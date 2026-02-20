'use strict';

const admin = require('firebase-admin');
const { randomUUID } = require('crypto');

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

// リストアコードのフォーマット: XXXX-XXXX-XXXX
// 文字セット: 23456789ABCDEFGHJKLMNPQRSTUVWXYZ (紛らわしい文字を除外)
const RESTORE_CODE_PATTERN =
  /^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}$/;

const responseHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
};

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: responseHeaders, body: '' };
  }

  try {
    const body = JSON.parse(event.body || '{}');
    const { code } = body;

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
    } else {
      // 新規コード: UID を生成して保存
      uid = randomUUID();
      await codeRef.set({
        uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const customToken = await admin.auth().createCustomToken(uid);

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
