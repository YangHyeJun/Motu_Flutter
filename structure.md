# Structure

## MVVM 원칙

- View는 화면 조립과 라우팅, 포커스 처리, 생명주기 브리지만 담당한다.
- ViewModel은 화면 상태, 실시간 구독 관리, 데이터 가공, 사용자 액션 처리 같은 비즈니스 로직을 담당한다.
- Model은 데이터 타입별로 파일을 분리하고, 해당 타입의 `copyWith`, 변환, 계산처럼 밀접한 동작만 같이 둔다.
- Repository는 API 호출, 응답 파싱, 외부 데이터 접근을 담당한다.
- 실시간 가격이 필요한 기능은 ViewModel이 소켓 스트림의 생명주기를 소유해야 한다.

## 탭 구조

- 각 탭은 기본적으로 `views/screens/<tab>_screen.dart`에 엔트리 화면을 둔다.
- 화면이 커지면 하위 UI는 `views/screens/<tab>_screen_sections.dart`, `views/screens/<tab>_screen_widgets.dart` 같은 보조 파일로 분리한다.
- 탭별 상태는 `viewmodels/<tab>_view_model.dart`, `viewmodels/<tab>_view_state.dart`로 관리한다.
- 탭 안에서 독립적인 기능 블록이 크면 별도 ViewModel 또는 별도 화면으로 분리한다.

## 실시간 구조

- 실시간 가격, 체결량, 연결 상태는 View가 직접 소켓을 관리하지 않는다.
- ViewModel이 `attachRealtime`, `detachRealtime`, `handleAppResumed`, `syncDisplayedStocks` 같은 메서드로 화면 생존 동안 실시간성을 유지한다.
- 사용자가 화면을 보고 있는 동안 가격이 변해야 하는 UI는 모두 스트림 기반으로 계속 갱신되어야 한다.
- REST 재조회는 소켓이 흔들릴 때의 보강 수단으로만 사용하고, 기본 동작은 스트림 기반 갱신이어야 한다.

## 상세 원칙

- 상세 화면에서만 필요한 호가/부가 실시간 데이터는 목록 화면 구독과 분리한다.
- 목록 화면은 가능한 한 “현재 보이는 종목” 기준으로만 구독한다.
- 같은 화면 안에서도 계산 로직, 정렬 로직, 포맷 결정 로직은 ViewModel 또는 전용 helper/ViewModel로 옮긴다.
- StatefulWidget이 필요하더라도 입력 컨트롤러, 애니메이션, 생명주기 브리지 같은 UI 상태만 View에 둔다.

## 현재 적용 방향

- Home 탭은 `HomeViewModel`과 section 파일 중심으로 유지한다.
- Stocks 탭은 화면 셸과 하위 section 파일을 분리하고, 실시간 구독 책임은 `StocksScreenViewModel`이 가진다.
- Favorites 탭은 실시간 구독 책임을 `FavoritesViewModel`이 가진다.
- More 탭은 계산/정렬 로직을 `MoreViewModel`로 분리하고, 화면은 렌더링 중심으로 유지한다.
