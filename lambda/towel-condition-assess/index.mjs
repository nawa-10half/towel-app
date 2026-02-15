import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

const SYSTEM_PROMPT = `あなたはタオルの状態を診断する専門家です。
ユーザーが送信したタオルの写真を分析し、以下の4項目を100点満点で評価してください。
点数が高いほど良い状態を意味します。

1. color_fading_score: 色褪せ（100=鮮やかな色、0=完全に色褪せている）
2. stain_score: 汚れ（100=汚れなし、0=ひどい汚れ）
3. fluffiness_score: ふわふわ感（100=新品同様のふわふわ、0=完全にペタンコ）
4. fraying_score: ほつれ（100=ほつれなし、0=ひどいほつれ）

また、overall_score として4項目の総合評価を100点満点で算出してください（単純平均でなく、状態の深刻さを考慮した総合判断）。

日本語でコメント（comment）と推奨アクション（recommendation）も提供してください。

必ず以下のJSON形式のみで回答してください。JSON以外のテキストは含めないでください:
{
  "overall_score": <number>,
  "color_fading_score": <number>,
  "stain_score": <number>,
  "fluffiness_score": <number>,
  "fraying_score": <number>,
  "comment": "<string>",
  "recommendation": "<string>"
}`;

export const handler = async (event) => {
  try {
    const body = JSON.parse(event.body);
    const { image, towel_name, towel_location } = body;

    if (!image) {
      return {
        statusCode: 400,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "image is required" }),
      };
    }

    const userMessage = towel_name
      ? `このタオル「${towel_name}」（設置場所: ${towel_location || "不明"}）の状態を診断してください。`
      : "このタオルの状態を診断してください。";

    const response = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: "image/jpeg",
                data: image,
              },
            },
            {
              type: "text",
              text: userMessage,
            },
          ],
        },
      ],
    });

    const textContent = response.content.find((c) => c.type === "text");
    if (!textContent) {
      return {
        statusCode: 500,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "No text response from Claude" }),
      };
    }

    // Extract JSON from response (handle markdown code block wrapper)
    const jsonMatch = textContent.text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return {
        statusCode: 500,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          error: "Failed to parse assessment result",
          raw: textContent.text,
        }),
      };
    }

    const assessment = JSON.parse(jsonMatch[0]);

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(assessment),
    };
  } catch (error) {
    console.error("Error:", error);

    let statusCode = 500;
    let message = "サーバーで予期しないエラーが発生しました";

    if (error.status === 400) {
      statusCode = 400;
      message = "リクエストが不正です。画像データを確認してください";
    } else if (error.status === 401) {
      statusCode = 401;
      message = "APIの認証に失敗しました";
    } else if (error.status === 403 || error.message?.includes("credit balance")) {
      statusCode = 402;
      message = "APIのクレジット残高が不足しています";
    } else if (error.status === 429) {
      statusCode = 429;
      message = "リクエストが多すぎます。しばらく待ってから再試行してください";
    } else if (error.status === 529) {
      statusCode = 503;
      message = "APIが一時的に混み合っています。しばらく待ってから再試行してください";
    }

    return {
      statusCode,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ error: message }),
    };
  }
};
