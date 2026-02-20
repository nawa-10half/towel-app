'use strict';

const Alexa = require('ask-sdk-core');
const admin = require('firebase-admin');
const https = require('https');

// ── Firebase Admin 初期化 ────────────────────────────────────────────
// SERVICE_ACCOUNT 環境変数に base64 エンコードされたサービスアカウント JSON を設定すること
const serviceAccount = JSON.parse(
  Buffer.from(process.env.SERVICE_ACCOUNT_B64, 'base64').toString('utf8')
);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'kaetao-c43f1',
  });
}

const db = admin.firestore();

// ── Firebase トークン交換 ─────────────────────────────────────────────
// Alexa が保持している refresh token → ID token → UID
async function getUidFromRefreshToken(refreshToken) {
  const apiKey = process.env.FIREBASE_API_KEY;
  const body = JSON.stringify({
    grant_type: 'refresh_token',
    refresh_token: refreshToken,
  });

  const idToken = await new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: 'securetoken.googleapis.com',
        path: `/v1/token?key=${apiKey}`,
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Content-Length': body.length },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          const json = JSON.parse(data);
          if (json.id_token) resolve(json.id_token);
          else reject(new Error('Token exchange failed: ' + JSON.stringify(json)));
        });
      }
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });

  const decoded = await admin.auth().verifyIdToken(idToken);
  return decoded.uid;
}

// ── Firestore ヘルパー ────────────────────────────────────────────────
async function getTowelsRef(uid) {
  const userDoc = await db.collection('users').doc(uid).get();
  const groupId = userDoc.data()?.groupId;
  if (groupId) {
    return db.collection('groups').doc(groupId).collection('towels');
  }
  return db.collection('users').doc(uid).collection('towels');
}

// タオル一覧を取得（最新交換記録付き）
async function fetchTowels(uid) {
  const ref = await getTowelsRef(uid);
  const snapshot = await ref.get();

  const towels = await Promise.all(
    snapshot.docs.map(async (doc) => {
      const data = doc.data();
      // 最新の交換記録を取得
      const recordsSnap = await doc.ref
        .collection('records')
        .orderBy('exchangedAt', 'desc')
        .limit(1)
        .get();
      const lastExchanged = recordsSnap.empty
        ? null
        : recordsSnap.docs[0].data().exchangedAt?.toDate() ?? null;

      return {
        id: doc.id,
        name: data.name ?? 'タオル',
        exchangeIntervalDays: data.exchangeIntervalDays ?? 30,
        lastExchanged,
      };
    })
  );

  return towels;
}

// 交換記録を追加
async function recordExchange(uid, towelId) {
  const ref = await getTowelsRef(uid);
  await ref.doc(towelId).collection('records').add({
    exchangedAt: admin.firestore.FieldValue.serverTimestamp(),
    note: 'Alexa経由で記録',
  });
}

// ── ヘルパー ──────────────────────────────────────────────────────────
function daysSince(date) {
  if (!date) return null;
  return Math.floor((Date.now() - date.getTime()) / (1000 * 60 * 60 * 24));
}

function daysUntilDue(towel) {
  if (!towel.lastExchanged) return null;
  const elapsed = daysSince(towel.lastExchanged);
  return towel.exchangeIntervalDays - elapsed;
}

function getAccessToken(handlerInput) {
  return handlerInput.requestEnvelope.session?.user?.accessToken
    ?? handlerInput.requestEnvelope.context?.System?.user?.accessToken;
}

function accountNotLinkedResponse(handlerInput) {
  return handlerInput.responseBuilder
    .speak('Alexaアプリでかえたおのアカウント連携を完了してから、もう一度お試しください。')
    .withLinkAccountCard()
    .getResponse();
}

// ── ハンドラー ────────────────────────────────────────────────────────

// 起動
const LaunchRequestHandler = {
  canHandle(input) {
    return Alexa.getRequestType(input.requestEnvelope) === 'LaunchRequest';
  },
  async handle(input) {
    const token = getAccessToken(input);
    if (!token) return accountNotLinkedResponse(input);

    try {
      const uid = await getUidFromRefreshToken(token);
      const towels = await fetchTowels(uid);
      const speak = `かえたおです。タオルが${towels.length}枚登録されています。「状態を教えて」や「交換を記録して」と言ってみてください。`;
      return input.responseBuilder.speak(speak).reprompt('何かお手伝いできますか？').getResponse();
    } catch {
      return input.responseBuilder.speak('データの取得に失敗しました。しばらくしてからもう一度お試しください。').getResponse();
    }
  },
};

// タオルの状態確認
const GetTowelStatusHandler = {
  canHandle(input) {
    return (
      Alexa.getRequestType(input.requestEnvelope) === 'IntentRequest' &&
      Alexa.getIntentName(input.requestEnvelope) === 'GetTowelStatusIntent'
    );
  },
  async handle(input) {
    const token = getAccessToken(input);
    if (!token) return accountNotLinkedResponse(input);

    try {
      const uid = await getUidFromRefreshToken(token);
      const towels = await fetchTowels(uid);

      if (towels.length === 0) {
        return input.responseBuilder.speak('タオルが登録されていません。アプリから登録してください。').getResponse();
      }

      const parts = towels.map((t) => {
        const days = daysSince(t.lastExchanged);
        if (days === null) return `${t.name}はまだ交換記録がありません`;
        return `${t.name}は${days}日前に交換しました`;
      });

      const speak = parts.join('。') + '。';
      return input.responseBuilder.speak(speak).getResponse();
    } catch {
      return input.responseBuilder.speak('データの取得に失敗しました。').getResponse();
    }
  },
};

// 交換期限確認
const CheckExchangeDeadlineHandler = {
  canHandle(input) {
    return (
      Alexa.getRequestType(input.requestEnvelope) === 'IntentRequest' &&
      Alexa.getIntentName(input.requestEnvelope) === 'CheckExchangeDeadlineIntent'
    );
  },
  async handle(input) {
    const token = getAccessToken(input);
    if (!token) return accountNotLinkedResponse(input);

    try {
      const uid = await getUidFromRefreshToken(token);
      const towels = await fetchTowels(uid);

      const overdue = towels.filter((t) => {
        const d = daysUntilDue(t);
        return d !== null && d <= 0;
      });
      const soon = towels.filter((t) => {
        const d = daysUntilDue(t);
        return d !== null && d > 0 && d <= 7;
      });
      const noRecord = towels.filter((t) => t.lastExchanged === null);

      const parts = [];
      if (overdue.length > 0) {
        parts.push(`交換時期を過ぎているのは、${overdue.map((t) => t.name).join('と')}です`);
      }
      if (soon.length > 0) {
        parts.push(`1週間以内に交換時期を迎えるのは、${soon.map((t) => `${t.name}（あと${daysUntilDue(t)}日）`).join('と')}です`);
      }
      if (noRecord.length > 0) {
        parts.push(`${noRecord.map((t) => t.name).join('と')}は交換記録がありません`);
      }
      if (parts.length === 0) {
        parts.push('交換が必要なタオルはありません');
      }

      return input.responseBuilder.speak(parts.join('。') + '。').getResponse();
    } catch {
      return input.responseBuilder.speak('データの取得に失敗しました。').getResponse();
    }
  },
};

// 交換を記録（タオルが1枚の場合は自動選択、複数の場合は名前スロット使用）
const RecordExchangeHandler = {
  canHandle(input) {
    return (
      Alexa.getRequestType(input.requestEnvelope) === 'IntentRequest' &&
      Alexa.getIntentName(input.requestEnvelope) === 'RecordExchangeIntent'
    );
  },
  async handle(input) {
    const token = getAccessToken(input);
    if (!token) return accountNotLinkedResponse(input);

    try {
      const uid = await getUidFromRefreshToken(token);
      const towels = await fetchTowels(uid);

      if (towels.length === 0) {
        return input.responseBuilder.speak('タオルが登録されていません。').getResponse();
      }

      // スロットから名前を取得
      const slots = input.requestEnvelope.request?.intent?.slots;
      const towelNameSlot = slots?.TowelName?.value;

      let target;
      if (towels.length === 1) {
        target = towels[0];
      } else if (towelNameSlot) {
        target = towels.find((t) =>
          t.name.includes(towelNameSlot) || towelNameSlot.includes(t.name)
        );
        if (!target) {
          const names = towels.map((t) => t.name).join('、');
          return input.responseBuilder
            .speak(`「${towelNameSlot}」というタオルが見つかりませんでした。登録されているのは、${names}です。どのタオルを記録しますか？`)
            .reprompt('どのタオルを記録しますか？')
            .getResponse();
        }
      } else {
        const names = towels.map((t) => t.name).join('、');
        return input.responseBuilder
          .speak(`どのタオルを交換しましたか？登録されているのは、${names}です。`)
          .reprompt('どのタオルを記録しますか？')
          .getResponse();
      }

      await recordExchange(uid, target.id);
      return input.responseBuilder
        .speak(`${target.name}の交換を記録しました。`)
        .getResponse();
    } catch {
      return input.responseBuilder.speak('記録に失敗しました。もう一度お試しください。').getResponse();
    }
  },
};

// セッション終了・エラー
const SessionEndedHandler = {
  canHandle(input) {
    return Alexa.getRequestType(input.requestEnvelope) === 'SessionEndedRequest';
  },
  handle(input) {
    return input.responseBuilder.getResponse();
  },
};

const ErrorHandler = {
  canHandle() { return true; },
  handle(input, error) {
    console.error('Error:', error);
    return input.responseBuilder
      .speak('エラーが発生しました。もう一度お試しください。')
      .getResponse();
  },
};

// ── エクスポート ──────────────────────────────────────────────────────
exports.handler = Alexa.SkillBuilders.custom()
  .addRequestHandlers(
    LaunchRequestHandler,
    GetTowelStatusHandler,
    CheckExchangeDeadlineHandler,
    RecordExchangeHandler,
    SessionEndedHandler,
  )
  .addErrorHandlers(ErrorHandler)
  .create()
  .invoke;
