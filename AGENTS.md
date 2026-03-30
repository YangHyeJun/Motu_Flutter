## Project 설명

- 본 프로젝트는 주식 앱이다.

## Project 구조

- MVVM 아키텍처 기반
- MVVM 구조와 화면/실시간 분리 원칙은 `structure.md`를 우선 참고한다.
- Model 에서 각 데이터 타입은 하나의 파일에 넣는다. 관련된 동작 (copy 등)이 있는 경우에는 같은 파일에 작성한다.
- 각 화면 (Splash, Home, 주식, 더보기, 알림)은 각각 view에서 프로젝트 파일을 분리한다. viewModel은 view와 1:1 또는 1:N (필요에 맞게) 구조를 가져간다.
- 중복된 코드는 최소화 한다.
- 실시간성을 보장하기 위해 socket 연결이 끊기지 않고 실시간성이 필요한 모든 화면에서 실시간성이 보장되어야 한다.
- View와 ViewModel을 확실히 구분한다.
- View는 Stateless 로 구현하고, provider 등의 변화되는 값들은 viewModel에서 관리한다.
  - 어쩔 수 없는 Stateful이 필요한 경우에는 사용이 가능하다.
- Extension을 활용하여 각 View, ViewModel에서도 분리를 확실하게 한다.
- ViewModel에는 비즈니스 로직이 있어야 한다.
- UseCase를 필요시 도입한다.

## 디자인

- motu_flutter/design 디렉토리 참조
- plash 화면 구현은 motu_flutter/design/splash 참고
- main 화면은 세로로 스크롤이 가능하며, main_home1 - main_home2 ... 순서로 스크롤 내렸을 때 보여져야 하는 화면이다.
    - 전체 예시 메인 화면은 main_home 처럼 보여져야 한다.
- 더보기 버튼을 클릭하면 detail 디렉토리를 확인한다.
    - 예시로 main 화면에서 보유주식 디테일을 누른경우 main_my_stocks_detail 화면처럼 보여져야 한다.
    - 공매도 순위 더보기 누른경우 short_sell_detail 처럼 보여져야 한다.
    - 특정 주식 하나를 누른 경우에는 stock_detail 처럼 보여진다.
- 각 화면에서 새로고침이 필요한 경우, 화면 최상단을 다시 내리면 새로고침을 추가하고, 보유 자산과 마켓 요약 등 실시간으로 변동되는 부분에는 새로고침 버튼을 추가한다.
- 다크모드를 지원한다.

## 서버

- 서버 호출하는데 필요한 접근 토큰을 얻는 정보와 관련된 문서는 motu_flutter/server/getAccessTokens.xlsx 를 참고한다.
- 전체 API 문서는 motu_flutter/server/openAPI.xlsx에 저장되어 있다.
- 실시간 시세 (WebSocket 방식) 관련된 Github 문서는 이 링크를 참고한다. https://github.com/koreainvestment/open-trading-api/tree/main/stocks_info

## 계좌 정보
- 실제 계정 정보는 Git에 저장하지 않는다.
- 로컬 실행 시 `--dart-define` 또는 `--dart-define-from-file=env/kis.local.json`을 사용한다.
- 필요한 키: `KIS_APP_KEY`, `KIS_APP_SECRET`, `KIS_ACCOUNT_NO`, `KIS_ACCOUNT_PRDT_CD`, `KIS_USE_MOCK`

## 저장소
- 커밋 후 푸시할 때는 appKey, appSecret이 절대로 노출되지 않도록 한다.

## 동작 후
- 이 AGENTS.md 파일을 참고했다는 의미로 빨간색 하트 이모지를 남긴다.

## 동작 사양
- .agent/requirements.md를 참고한다.

## 코딩 컨벤션
- .agent/code_conventions.md를 참고한다.
