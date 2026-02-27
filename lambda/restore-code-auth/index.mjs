import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { randomUUID } from 'crypto';

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

// リストアコードのフォーマット: XXXX-XXXX-XXXX
// 文字セット: 23456789ABCDEFGHJKLMNPQRSTUVWXYZ (紛らわしい文字を除外)
const RESTORE_CODE_PATTERN =
  /^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}$/;

const responseHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export const handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: responseHeaders, body: '' };
  }

  try {
    const body = JSON.parse(event.body || '{}');
    const { code, newUser } = body;

    if (!code || !RESTORE_CODE_PATTERN.test(code)) {
      return {
        statusCode: 400,
        headers: responseHeaders,
        body: JSON.stringify({ error: 'Invalid restore code format' }),
      };
    }

    const codeRef = db.collection('restoreCodes').doc(code);
    const codeDoc = await codeRef.get();

    let uid;
    if (codeDoc.exists) {
      // 既存コード: UID を取得
      uid = codeDoc.data().uid;
    } else if (newUser === true) {
      // 新規ユーザーのみ新規作成を許可
      uid = randomUUID();
      await codeRef.set({
        uid,
        createdAt: FieldValue.serverTimestamp(),
      });
    } else {
      // 復元フローでコードが存在しない場合はエラー
      return {
        statusCode: 404,
        headers: responseHeaders,
        body: JSON.stringify({ error: 'Restore code not found' }),
      };
    }

    const customToken = await getAuth().createCustomToken(uid);

    return {
      statusCode: 200,
      headers: responseHeaders,
      body: JSON.stringify({ customToken }),
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: responseHeaders,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};
