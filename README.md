# Kkolkkak

약과 영양제 복용 시간, 남은 알약 수, 재구매 타이밍을 한 화면에서 챙기는 Flutter MVP입니다.

## MVP 기능

- 오늘 복용할 항목 보기
- 복용 완료 시 남은 알약 자동 차감
- 남은 일수 기반 재구매 경고
- 신규 약/영양제 추가, 수정, 삭제
- 요일별 반복 복용 스케줄
- 로컬 알림 예약
- 앱을 껐다 켜도 유지되는 로컬 저장
- 복용 후 컨디션 체크인
- 자주 놓치는 시간대와 컨디션 메모를 보여주는 작은 인사이트

## 실행

```bash
flutter pub get
flutter run
```

## 검증

```bash
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

Windows에서 프로젝트 경로에 한글이 포함되면 Flutter shader 출력이 실패할 수 있습니다. Android/Web 빌드 산출물 검증은 ASCII 경로에서 실행하는 것을 권장합니다.
