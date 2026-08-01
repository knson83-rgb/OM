const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type RecipeItem = {
  name: string;
  qty: number;
  unit: string;
  type: "main" | "seasoning";
};

const seasoningKeywords = [
  "간장",
  "고추장",
  "된장",
  "고춧가루",
  "소금",
  "설탕",
  "후추",
  "물엿",
  "올리고당",
  "미림",
  "맛술",
  "식초",
  "참치액",
  "굴소스",
  "액젓",
  "식용유",
  "들기름",
  "참기름",
  "다시다",
  "육수",
  "전분",
  "두반장",
  "치킨스톡",
  "고추기름",
  "케첩",
  "카레가루",
];

const units = ["kg", "g", "ml", "L", "개", "인분", "큰술", "작은술", "컵", "모", "봉지", "팩", "장", "대", "통"];
const knownIngredients = [
  "두부",
  "순두부",
  "돼지고기",
  "돼지고기다짐육",
  "다진 돼지고기",
  "소고기",
  "닭고기",
  "새우",
  "오징어",
  "양파",
  "대파",
  "쪽파",
  "실파",
  "마늘",
  "다진마늘",
  "다진 마늘",
  "생강",
  "청양고추",
  "홍고추",
  "청고추",
  "피망",
  "파프리카",
  "당근",
  "감자",
  "양배추",
  "애호박",
  "버섯",
  "표고버섯",
  "팽이버섯",
  "느타리버섯",
  "고추기름",
  "식용유",
  "참기름",
  "들기름",
  "간장",
  "진간장",
  "국간장",
  "된장",
  "고추장",
  "두반장",
  "굴소스",
  "설탕",
  "소금",
  "후추",
  "고춧가루",
  "전분",
  "전분가루",
  "두반장",
  "치킨스톡",
  "고추기름",
  "맛술",
  "미림",
  "물",
  "육수",
  "치킨스톡",
  "밥",
];

function autoType(name: string): "main" | "seasoning" {
  return seasoningKeywords.some((keyword) => name.includes(keyword)) ? "seasoning" : "main";
}

function normalizeName(raw: string) {
  return raw
    .replace(/구매/g, " ")
    .replace(/약간|톡톡|적당량|조금|조금만/g, " ")
    .replace(/^[\s\-*•·:]+/, "")
    .replace(/[()[\]{}]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function canonicalIngredientName(raw: string) {
  const normalized = normalizeName(raw);
  const compact = normalized.replace(/\s+/g, "");
  if (units.includes(normalized) || /종이컵|계량컵|밥숟가락|티스푼|큰술|작은술/.test(normalized)) return "";
  const sorted = [...knownIngredients].sort((a, b) => b.length - a.length);
  const found = sorted.find((name) => compact.includes(name.replace(/\s+/g, "")));
  if (found) return found.replace("돼지고기다짐육", "돼지고기 다짐육").replace("다진마늘", "다진마늘");
  return "";
}

function extractItems(text: string): RecipeItem[] {
  const escapedUnits = units.map((unit) => unit.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|");
  const pattern = new RegExp(`([가-힣A-Za-z/()\\s]{1,20})\\s*([0-9]+(?:\\.[0-9]+)?)\\s*(${escapedUnits})`, "g");
  const seen = new Set<string>();
  const items: RecipeItem[] = [];
  let match: RegExpExecArray | null;

  while ((match = pattern.exec(text)) && items.length < 24) {
    const name = canonicalIngredientName(match[1]);
    const qty = Number(match[2]);
    const unit = match[3];
    if (!name || !Number.isFinite(qty) || qty <= 0) continue;
    if (name.length < 1 || /레시피|재료|만드는|조리|출처|검색|요리|분량|기준/.test(name)) continue;
    if (unit === "인분" && name !== "밥") continue;
    const key = name;
    if (seen.has(key)) continue;
    seen.add(key);
    items.push({ name, qty, unit, type: autoType(name) });
  }

  return items;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "POST only" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const apiKey = Deno.env.get("JINA_API_KEY");
    if (!apiKey) {
      throw new Error("JINA_API_KEY is not configured");
    }

    const body = await req.json();
    const menuName = String(body.menuName || "").trim();
    if (!menuName) throw new Error("menuName is required");

    const query = encodeURIComponent(`${menuName} 레시피 재료 양념 분량`);
    const searchRes = await fetch(`https://s.jina.ai/${query}`, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        Accept: "text/plain",
        "X-Respond-With": "text",
      },
    });

    if (!searchRes.ok) {
      throw new Error(`Jina search failed: ${searchRes.status}`);
    }

    const text = await searchRes.text();
    const items = extractItems(text);

    return new Response(JSON.stringify({
      name: menuName,
      source: "웹 검색",
      baseServings: 1,
      level: items.length >= 6 ? "검색" : "낮음",
      items,
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : "unknown error" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
