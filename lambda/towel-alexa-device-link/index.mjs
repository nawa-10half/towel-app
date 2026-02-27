import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import https from 'https';

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

// ── Firebase カスタムトークン → リフレッシュトークン交換 ──────────────
async function exchangeCustomTokenForRefreshToken(customToken) {
  const apiKey = process.env.FIREBASE_API_KEY;
  const body = JSON.stringify({ token: customToken, returnSecureToken: true });

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: 'identitytoolkit.googleapis.com',
        path: `/v1/accounts:signInWithCustomToken?key=${apiKey}`,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          const json = JSON.parse(data);
          if (json.refreshToken) resolve(json.refreshToken);
          else reject(new Error('Token exchange failed: ' + JSON.stringify(json)));
        });
      }
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// ── CORS ヘッダー ────────────────────────────────────────────────────
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};

// ── Lambda ハンドラー ─────────────────────────────────────────────────
export const handler = async (event) => {
  // CORS preflight
  const method = event.requestContext?.http?.method ?? event.httpMethod;
  if (method === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  try {
    const { code } = JSON.parse(event.body || '{}');
    if (!code || typeof code !== 'string') {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: '無効なコードです' }),
      };
    }

    const normalizedCode = code.trim().toUpperCase();
    const codeRef = db.collection('linkingCodes').doc(normalizedCode);
    const codeDoc = await codeRef.get();

    if (!codeDoc.exists) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'コードが見つかりません' }),
      };
    }

    const data = codeDoc.data();
    const expiresAt = data.expiresAt?.toDate();
    if (!expiresAt || expiresAt < new Date()) {
      await codeRef.delete();
      return {
        statusCode: 410,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'コードの有効期限が切れています' }),
      };
    }

    const uid = data.uid;
    await codeRef.delete(); // ワンタイム使用

    const customToken = await getAuth().createCustomToken(uid);
    const refreshToken = await exchangeCustomTokenForRefreshToken(customToken);

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ refreshToken }),
    };
  } catch (err) {
    console.error('Error:', err);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Internal server error' }),
    };
  }
};
