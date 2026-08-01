# 레시피 검색 자동 생성 설정

DB에 없는 음식은 프론트에서 먼저 저장/내장 레시피를 찾고, 없으면 `recipeSearchEndpoint`로 검색 요청을 보냅니다.

## 1. Supabase Edge Function 배포

```bash
supabase functions deploy recipe-search
```

## 2. Jina Search API Key 설정

Jina Search는 `s.jina.ai` 검색 API를 사용합니다. API 키는 프론트에 넣지 말고 Supabase secret으로 설정합니다.

```bash
supabase secrets set JINA_API_KEY=지나_API_KEY
```

## 3. config.js 설정

배포 후 Function URL을 `config.js`에 넣습니다.

```js
window.SUPABASE_CONFIG = {
  url: "https://프로젝트.supabase.co",
  key: "sb_publishable_...",
  recipeSearchEndpoint: "https://프로젝트.supabase.co/functions/v1/recipe-search",
  recipeSearchKey: ""
};
```

`recipeSearchKey`는 보통 비워둡니다. Function 자체에 별도 인증을 추가한 경우에만 사용합니다.

## 동작 순서

1. 저장된 DB 레시피 검색
2. 내장 템플릿 검색
3. 검색 API 호출
4. 검색 실패 또는 결과 부족 시 기본 키워드 추정 사용

