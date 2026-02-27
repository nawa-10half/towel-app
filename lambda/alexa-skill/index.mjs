import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import https from 'https';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const Alexa = require('ask-sdk-core');

// ── Firebase Admin 初期化 ────────────────────────────────────────────
const serviceAccount = JSON.parse(
  Buffer.from(process.env.SERVICE_ACCOUNT_B64, 'base64').toString('utf8')
);

if (!getApps().length) {
  initializeApp({
    credential: cert(serviceAccount),
    projectId: 'kaetao-c43f1',
  });
}

const db = getFirestore();

// ── Firebase トークン交換 ─────────────────────────────────────────────
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

  const decoded = await getAuth().verifyIdToken(idToken);
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

async function fetchTowels(uid) {
  const ref = await getTowelsRef(uid);
  const snapshot = await ref.get();

  return snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: data.name ?? 'タオル',
      exchangeIntervalDays: data.exchangeIntervalDays ?? 30,
      lastExchanged: data.lastExchangedAt?.toDate() ?? null,
    };
  });
}

async function recordExchange(uid, towelId) {
  const ref = await getTowelsRef(uid);
  const batch = db.batch();

  const recordRef = ref.doc(towelId).collection('records').doc();
  batch.set(recordRef, {
    exchangedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    note: 'Alexa経由で記録',
  });

  batch.update(ref.doc(towelId), {
    lastExchangedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await batch.commit();
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
    .speak('Alexaアプリでかえたおアプリのアカウント連携を完了してから、もう一度お試しください。')
    .withLinkAccountCard()
    .getResponse();
}

// ── ハンドラー ────────────────────────────────────────────────────────

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
      const speak = `かえたおアプリです。タオルが${towels.length}枚登録されています。「状態を教えて」や「交換を記録して」と言ってみてください。`;
      return input.responseBuilder.speak(speak).reprompt('何かお手伝いできますか？').getResponse();
    } catch {
      return input.responseBuilder.speak('データの取得に失敗しました。しばらくしてからもう一度お試しください。').getResponse();
    }
  },
};

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

      const slots = input.requestEnvelope.request?.intent?.slots;
      const towelNameSlot = slots?.TowelName?.value;
      const numberSlot = parseInt(slots?.TowelNumber?.value);
      const attrs = input.attributesManager.getSessionAttributes();

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
            .speak(`「${towelNameSlot}」というタオルが見つかりませんでした。登録されているのは、${names}です。`)
            .reprompt('どのタオルを記録しますか？')
            .getResponse();
        }
      } else if (!isNaN(numberSlot) && attrs.pendingTowelIds) {
        const pendingTowelIds = attrs.pendingTowelIds;
        target = towels.find(t => t.id === pendingTowelIds[numberSlot - 1]);
        if (!target) {
          const max = pendingTowelIds.length;
          return input.responseBuilder
            .speak(`1から${max}の番号で答えてください。`)
            .reprompt(`1から${max}の番号で答えてください。`)
            .getResponse();
        }
      } else {
        const numbered = towels.map((t, i) => `${i + 1}番、${t.name}`).join('。');
        input.attributesManager.setSessionAttributes({ pendingTowelIds: towels.map(t => t.id) });
        return input.responseBuilder
          .speak(`複数のタオルが登録されています。${numbered}。交換したのは何番ですか？「交換したのは1」のように答えてください。`)
          .reprompt('交換したのは何番ですか？「交換したのは1」のように答えてください。')
          .getResponse();
      }

      await recordExchange(uid, target.id);
      return input.responseBuilder
        .speak(`${target.name}の交換を記録しました。`)
        .getResponse();
    } catch (error) {
      console.error('RecordExchange error:', error);
      return input.responseBuilder.speak('記録に失敗しました。もう一度お試しください。').getResponse();
    }
  },
};

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
    console.error('Alexa handler error:', error?.message);
    return input.responseBuilder
      .speak('エラーが発生しました。もう一度お試しください。')
      .getResponse();
  },
};

// ── エクスポート ──────────────────────────────────────────────────────
export const handler = Alexa.SkillBuilders.custom()
  .addRequestHandlers(
    LaunchRequestHandler,
    GetTowelStatusHandler,
    CheckExchangeDeadlineHandler,
    RecordExchangeHandler,
    SessionEndedHandler,
  )
  .addErrorHandlers(ErrorHandler)
  .lambda();
