# 직원 식단 발주 관리 Supabase 연동

## 1. Supabase DB 생성

Supabase Dashboard에서 프로젝트를 열고 `SQL Editor`에 들어간 뒤, 이 폴더의 `schema.sql` 전체 내용을 실행합니다.

생성되는 주요 테이블:

- `recipes`: 메뉴
- `recipe_ingredients`: 메뉴별 재료
- `inventory`: 재고
- `draft_orders`: 확정 전 임시 발주
- `final_orders`: 최종 발주
- `final_order_items`: 최종 발주 품목

## 2. 로그인 없는 관리 화면 권한 적용

이 앱은 별도 로그인 화면 없이 내부 관리자가 바로 데이터를 관리하는 구조입니다.

`schema.sql` 실행 후 Supabase `SQL Editor`에서 `public_access_patch.sql`도 실행합니다.

브라우저에서 사용하는 키는 `Publishable Key` 또는 `Anon Key`만 넣어야 합니다. `service_role` 또는 Secret Key는 절대 `config.js`에 넣지 마세요.

## 3. Supabase 설정

`config.js`에서 프로젝트 URL과 브라우저용 키를 확인합니다.

```js
window.SUPABASE_CONFIG = {
  url: "https://hzlgqijhhajgvpymukak.supabase.co",
  key: "sb_publishable_..."
};
```

## 4. 로컬 실행

이 폴더에서 다음 명령을 실행합니다.

```bash
python3 -m http.server 8000
```

브라우저에서 접속합니다.

```text
http://127.0.0.1:8000
```

## 5. 사용 순서

1. `메뉴/재료`에서 메뉴와 재료 확인 또는 추가
2. `재고`에서 현재 보유 수량 등록
3. `임시 발주`에서 구매할 품목 추가
4. `발주 확정`을 눌러 최종 발주내역 저장

## 보안 메모

`public_access_patch.sql`은 Publishable/Anon Key로 CRUD를 허용합니다. 내부 도구처럼 접근 URL을 통제할 수 있는 환경에서 쓰는 구성이며, 외부 공개 서비스라면 별도 백엔드 API와 관리자 인증을 두는 편이 맞습니다.
