/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {onRequest, onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {setGlobalOptions} from "firebase-functions/v2";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
// import the Genkit and Google AI plugin libraries
import {gemini15Pro, googleAI} from "@genkit-ai/googleai";
import express from "express";
import {genkit} from "genkit/beta";
import {z} from "zod";


const app = express();


// Firebase Adminの初期化
initializeApp();

setGlobalOptions({timeoutSeconds: 540});

// configure a Genkit instance
const ai = genkit({
  plugins: [googleAI({apiKey: process.env.GOOGLE_GENAI_API_KEY})],
  model: gemini15Pro, // set default model
});

type Requirements = {
  area: string;
  purpose: string;
  start: string;
  end: string;
  budget: string;
  otherRequest: string;
};

// Start writing functions
// https://firebase.google.com/docs/functions/typescript
// Take the text parameter passed to this HTTP endpoint and insert it into
// Firestore under the path /messages/:documentId/original
app.post("/", async (req, res) => {
  // Grab the text parameter.
  const area = req.body.area;
  const purpose = req.body.purpose;
  const start = req.body.start;
  const end = req.body.end;
  const otherRequest = req.body.otherRequest;
  const budget = req.body.budget;

  const requirements = {
    area,
    purpose,
    start,
    end,
    budget,
    otherRequest,
  } as Requirements;

  // Push the new message into Firestore using the Firebase Admin SDK.
  const writeResult = await getFirestore()
    .collection("plans")
    .add({requirements});
    // Send back a message that we've successfully written the message
  res.json({messageId: writeResult.id});
});

exports.createPlan = onRequest(app);

exports.onCallCreatePlan = onCall<Requirements, Promise<{planId: string}>>(async (data, context) => {
  // リクエストパラメータの取得とバリデーション
  const {area, purpose, start, end, budget, otherRequest} = data.data;

  const requirements: Requirements = {
    area,
    purpose,
    start,
    end,
    budget,
    otherRequest,
  };

  try {
    const docRef = await getFirestore()
      .collection("plans")
      .add({requirements});

    // クライアント側が planId を期待している場合
    return {planId: docRef.id};
  } catch (error) {
    console.error("プラン作成中にエラーが発生しました:", error);
    throw new HttpsError(
      "internal",
      "プラン作成中に内部サーバーエラーが発生しました"
    );
  }
});


/**
 * テキスト検索クエリを実行する関数
 *
 * @param query 検索クエリ
 * @return 検索結果
 */
async function searchTextQuery(query: string) {
  const url = "https://places.googleapis.com/v1/places:searchText";

  // 取得したいフィールドをカンマ区切りで指定
  const fieldMask = [
    "places.displayName",
    "places.formattedAddress",
    "places.types",
    "places.websiteUri",
    "places.reviews.text.text",
    "places.reviews.rating",
    "places.photos.name",
    "places.rating",
    "places.userRatingCount",
    "places.regularOpeningHours.weekdayDescriptions",
    "places.priceRange",
  ].join(",");

  // ヘッダーを設定
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "X-Goog-Api-Key": process.env.GOOGLE_API_KEY || "",
    "X-Goog-FieldMask": fieldMask,
  };

  // リクエストボディ
  const payload = {
    textQuery: query,
    maxResultCount: 10,
    languageCode: "ja",
  };

  // POST リクエスト
  const response = await fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    // 必要に応じてエラー処理を実装
    throw new Error(
      `Failed to fetch search results: 
      ${response.status} ${response.statusText}`);
  }

  // places: [...] の形で結果が返ってくる想定
  const data = await response.json();

  // 取得結果を整形（photoUri は非同期取得なので Promise.all で処理）
  const places = await Promise.all(
    (data.places || []).map(async (place: any) => {
      return {
        name: place?.displayName?.text ?? null,
        address: place?.formattedAddress ?? null,
        types: place?.types ?? [],
        website: place?.websiteUri ?? null,
        reviews: place?.reviews?.map((review: { rating: any; text: { text: any; }; }) => {
          return {rating: review.rating, text: review.text?.text ?? null};
        }) ?? [],
        userReviewCount: place?.userRatingCount ?? null,
        rating: place?.rating ?? null,
        photoUri:
          place?.photos && place?.photos[0] ?
            await getPhoto(place.photos[0].name) :
            null,
        businessHour: place?.regularOpeningHours?.weekdayDescriptions ?? [],
        minPrice: getPrice(place?.priceRange?.startPrice),
        maxPrice: getPrice(place?.priceRange?.endPrice),
      };
    })
  );

  return places;
}

/**
 * 価格を取得する関数
 *
 * @param price 価格情報
 * @return 価格文字列
 */
function getPrice(
  price?: { units?: number | string; currencyCode?: string }
): string | null {
  if (!price || price.units == null || !price.currencyCode) {
    return null;
  }
  return `${price.units}${price.currencyCode}`;
}

/**
 * 写真のURIを取得する関数
 * @param name Places APIの写真名
 */
async function getPhoto(name: string): Promise<string | null> {
  const url = `https://places.googleapis.com/v1/${name}/media?maxHeightPx=400&maxWidthPx=400&skipHttpRedirect=true`;

  const headers = {
    "X-Goog-Api-Key": process.env.GOOGLE_API_KEY || "",
  };

  const response = await fetch(url, {headers});
  if (!response.ok) {
    // 必要に応じてエラー処理を実装
    return null;
  }

  const data = await response.json();

  return data?.photoUri ?? null;
}

const searchPlaceTool = ai.defineTool(
  {
    name: "searchPlaceTool",
    description: `Get place information from the backend.
                  Returns detailed information, including its name, 
                  address, types, reviews, average rating, and photo URL.`,
    inputSchema: z.object({
      query: z.string().describe("The query to search. e.g. restaurant name, spot name, etc."),
    }),
    outputSchema: z.array(z.object({
      name: z.string().nullable().describe("The name of the place."),
      address: z.string().nullable().describe("The address of the place."),
      types: z.array(z.string()).nullable().describe("A list of place types (e.g., \"transit_place\", \"train_place\")."),
      reviews: z.array(z.object({
        rating: z.number().describe("Rating out of 5."),
        text: z.string().nullable().describe("The review content."),
      })).nullable().describe("A list of top 5 reviews, each containing: rating (int): Rating out of 5, text (dict): A dictionary with \"text\" containing the review content."),
      userReviewCount: z.number().nullable().describe("The number of user reviews."),
      rating: z.number().nullable().describe("The average rating of the place."),
      photoUri: z.string().nullable().describe("URL of a photo representing the place."),
      businessHour: z.array(z.string().nullable().describe("The business status of the place.")),
      website: z.string().nullable().describe("URL of the place's website."),
      minPrice: z.string().nullable().describe("The minimum price of the place."),
      maxPrice: z.string().nullable().describe("The maximum price of the place."),
    })).describe("A list of dictionaries, where each dictionary represents a place and contains the following keys: name (str): The name of the place, address (str): The address of the place, types (list of str): A list of place"),

  },
  async (input) => {
    logger.info("using searchPlaceTool with query:", input.query);
    return await searchTextQuery(input.query);
  }
);

const searchSpotAgent = ai.definePrompt(
  {
    name: "searchSpotAgent",
    description: "A retrieval AI that searches for information about tourist spots.",
    tools: [searchPlaceTool],
  },
  `{{role "system"}} searchPlaceToolを使用して、プラン内のすべての観光スポットに関する情報やレビューを取得してください。
  もし観光スポットが特定の施設や店舗でない場合は、searchPlaceToolを使用して周りの観光スポットを取得し、その情報から適切なスポットを提案してください。
  各スポットについては
  #### スポット名{{spotName}}
  - アクティビティ：{{activity}}
  - おすすめ理由：{{reason}}
  - クチコミ評価：{{rating}} ({{ratingCount}}件)
  - クチコミの声： {{review}} : 複数のクチコミがある場合は複数記載してください
  - 営業時間：{{businessHours}}
  - 所要時間(目安):{{duration}}
  - 最低価格： {{minPrice}}
  - 最大価格 : {{maxPrice}}
  - Webサイト    :[spotName]({{websiteUrl}})
  - 写真URL : {{photoUri}}`
);

const plannerAgent = ai.definePrompt(
  {
    name: "plannerAgent",
    description: "A travel planner AI that helps users plan their trips.",
  },
  `{{role "system"}} あなたは観光案内AIとして振る舞います。ユーザーからの旅行プランに関する要望を受け付け、以下の点に注意しながら回答してください。
  - ユーザーの興味を優先:旅行先や興味のカテゴリをもとに、適切な観光スポットや体験を提案してください。
  - 一日ごとにテーマを設定:1日の観光プランを提案する際には、その日のテーマ（例:グルメ、観光スポット巡り、アクティビティ）を設定してください。
  - 長期旅行の場合:3日以上の長期旅行の場合は、数日ごとにまとめて提案文を記載してください。
  - 旅程を提案する際の形式:スポット名、そこで行うこと（アクティビティ）、おすすめ理由、訪問日などをわかりやすく提示してください。
  - してはいけないこと:個人情報（住所や電話番号など）を直接聞き出す行為や、法的・倫理的に問題がある行為を助長する提案は行わないでください。公序良俗に反する内容の回答は避けてください。確認できない情報を推測で回答しないでください。Googleの検索URLは貼らないでください
  - トーン・スタイル:丁寧でフレンドリーな言葉遣いを心がけ、必要に応じて専門用語は噛み砕いて説明してください。もし答えが不明な場合は「現時点では不明」と伝え、追加情報を求めてください。
  - 目的:ユーザーが旅行計画をスムーズに立てられるようサポートすることが最優先です。`
);

const summaryAgent = ai.definePrompt(
  {
    name: "summaryAgent",
    description: "a summary AI that summarizes the travel plan",
  },
  `{{role "system"}} これまでの情報をもとに、旅行プランの提案文をまとめてください。提案文には各スポットのレビューはスポットごとに1つ記載してください
提案文は各日付に対して以下のフォーマットで記載してください。ただし3日以上の長期旅行の場合は、数日ごとにまとめて提案文を記載してください。
営業時間は日付に合わせて記載してください。もし定休日だったり休業中だったりする場合はそのスポットは提案しないでください。
末尾には注意事項を記載してください。
予算は各スポットの価格を元に旅行全体の予算を想定してください。
クチコミの文が長い場合は、適宜省略してください。またクチコミはポジティブなものや有益な情報を選んで記載してください。
この提案は一度しか行わないため、提案文をよく検討してから提出してください。

旅行プランの先頭には以下の情報を記載してください。
# {{planName}}
- 全体のテーマ：{{theme}}
- エリア名：{{area}}

## 全体の旅行プランの説明
この旅行プランは{{startDate}}から{{endDate}}までの{{duration}}日間の旅行プランです。
{{theme}}をテーマに、{{area}}を中心に観光スポットを巡ります。
このプランでは{{budget}}の予算を想定しています。

各日程には以下の情報を記載し、最終日まで続けてください。
クチコミは3件まで記載してください。
日付はyyyy-mm-ddの形式で記載してください。
一日の過ごし方は、その日のテーマに合わせて100文字程度で記載してください。

### 日付: {{date}}
- テーマ：{{theme}}
- 一日の過ごし方 : {{description}}
- 一日の過ごし方フロー：それぞれ最大6文字で記載してください。移動の場合は「xxへ移動」という記載にしてください。フローの内容がスポットであれば、そのスポットの写真URLを記載してください。
  - フロー1：{{morning}} {{spotPhotoUri}}
  - フロー2：{{afternoon}} {{spotPhotoUri}}
  - フロー3：{{evening}} {{spotPhotoUri}}
  - フロー4：{{night}} {{spotPhotoUri}}
- 旅行エリア：{{area}} {{spotPhotoUri}}
- 1日の推定予算：{{dayBudget}}
────────────────────────────────

#### スポット名：{{spotName}}
- アクティビティ：{{activity}}
- おすすめ理由：{{reason}}
- クチコミ評価：{{rating}} ({{ratingCount}}件)
- クチコミの声： {{review}} : 複数のクチコミがある場合は複数記載してください
  - 評点：{{rating}}
  - レビュー：{{text}}
- 写真URL : {{photoUri}} フローで記載されていたとしても必ず記載してください`);

// const managerAgent = ai.definePrompt(
//   {
//     name: 'managerAgent',
//     description: 'A manager AI each ai agent',
//     tools: [plannerAgent, searchSpotAgent, summaryAgent],
//   },
//   `{{role "system"}} あなたは観光案内AIとして振る舞います。plannerAgent, searchSpotAgent, summaryAgentを順番に使用して、ユーザーの旅行プランに関する要望を受け付け回答してください。最後の文章はmarkdown`
// );

const plannerChat = ai.chat(plannerAgent);
const searchSpotChat = ai.chat(searchSpotAgent);
const summaryChat = ai.chat(summaryAgent);

// Listens for new messages added to /messages/:documentId/original
// and saves an uppercased version of the message
// to /messages/:documentId/uppercase
exports.planAgent = onDocumentCreated("/plans/{documentId}",
  async (event) => {
    if (!event.data) {
      logger.error("No data in event");
      return;
    }

    // Grab the current value of what was written to Firestore.
    const requirements = event.data.data().requirements as Requirements;

    const requirementsMessage = `"旅行プランを考えてください。エリア: ${requirements.area}
      目的: 「${requirements.purpose}」のキーワードに基づいて観光スポットを提案してください。
      期間: ${requirements.start} ~ ${requirements.end}
      予算: ${requirements.budget}`;

    // Access the parameter `{documentId}` with `event.params`
    // logger.log("AI Response", event.params.documentId, original);

    const {text: plan} = await plannerChat.send(
      {prompt: requirementsMessage, config: {maxOutputTokens: 8000}});

    const {text: place} = await searchSpotChat.send(
      {prompt: plan, config: {maxOutputTokens: 8000}});

    const {text: summary} = await summaryChat.send(
      {prompt: requirementsMessage + plan + place, config: {maxOutputTokens: 8000}});

    const {output: suggestedPlan} = await ai.generate({
      prompt: "次の旅行プランの文章をJSONオブジェクトに変換してください。dayFlowのstartTimeにはスケジュールをもとにしたおおよその時刻を補完してください。" + summary,
      // Specify output structure using Zod schema
      output: {
        format: "json",
        schema: z.object({
          name: z.string().describe("The name of the plan."),
          theme: z.string().describe("The theme of the plan."),
          area: z.string().describe("The area of the plan."),
          description: z.string().describe("The description of the plan."),
          caution: z.array(z.string().describe("The caution of the plan.")),
          schedule: z.array(
            z.object({
              date: z.string().describe("The date of the schedule. e.g. 2022-12-31"),
              name: z.string().describe("The name of the schedule."),
              description: z.string().describe("The schedule of the day."),
              dayFlow: z.array(z.object({
                startTime: z.string().describe("The start time of the flow."),
                label: z.string().describe("The label of the flow."),
                // スポットではない場合はnull
                spotImageUrl: z.string().nullable().describe("The image URL of the spot. If This flow is not a spot, it should be null."),
              })),
              dayBudget: z.number().describe("The budget of the day."),
              area: z.string().describe("The area of the schedule."),
              spot: z.array(z.object({
                name: z.string().describe("The name of the spot."),
                activity: z.string().describe("The activity of the spot."),
                reason: z.string().describe("The reason of the spot."),
                rating: z.number().nullable().describe("The rating of the spot."),
                ratingCount: z.number().nullable().describe("The rating count of the spot."),
                review: z.array(z.object({
                  rating: z.number().describe("Rating out of 5."),
                  text: z.string().nullable().describe("The review content."),
                })),
                businessHours: z.array(z.string().nullable().describe("The business status of the spot.")),
                duration: z.number().describe("所要時間(目安)、単位は分"),
                minPrice: z.number().nullable().describe("The minimum price of the spot."),
                maxPrice: z.number().nullable().describe("The maximum price of the spot."),
                websiteUrl: z.string().nullable().describe("URL of the spot's website."),
                photoUri: z.string().nullable().describe("URL of a photo representing the spot."),
              })),
            })),
        }),
      },
    });

    const debug = {
      plan,
      place,
      summary,
    };

    // You must return a Promise when performing
    // asynchronous tasks inside a function
    // such as writing to Firestore.
    // Setting an 'uppercase' field in Firestore document returns a Promise.
    return event.data.ref.set({debug, suggestedPlan}, {merge: true});
  });

