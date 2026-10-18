# 세이원띵 - Say One Thing

한국어 사용자를 위한 하루 한 문장 영어 말하기 연습 앱입니다. 매일 질문 하나에 영어 한 문장을 녹음하고 연속 연습 기록을 쌓습니다. 채팅, 매칭, 프로필과 온보딩은 제공하지 않습니다.

## 실행

Gemini 키는 `GEMINI_API_KEY` 또는 Rails credentials의 `gemini.api_key`에 설정합니다. 모델은 `GEMINI_QUESTION_MODEL`로 변경하며 기본값은 `gemini-3.8-flash`입니다.

```sh
bin/rails db:migrate:reset && bin/rails db:seed
bin/rails server
```

DB 초기화는 개발·테스트 데이터를 삭제합니다. 첫 접속 시 오늘의 질문을 생성합니다. 키가 없거나 API 장애가 발생하면 샘플임을 표시한 질문을 제공합니다.

질문 번역, 질문에 맞는 한국어 예시, 한국어 답변의 영어 표현과 IPA를 제공합니다. 도움말 창 안에서 녹음·재생·재녹음·전송할 수 있습니다.

녹음은 1~60초, 최대 10MB입니다. 다른 사용자에게 공개하거나 Gemini에 전송하지 않습니다. 번역 요청 문장은 Gemini에 전송하며 DB에 저장하지 않습니다.

완료와 스트릭은 한국 시간 기준입니다. 하루 한 번 완료하며 다음 질문은 자정에 열립니다. 완료 화면에 다음 질문까지 남은 시간을 표시합니다.

```sh
bin/rails test
bin/rails test test/system/daily_practice_test.rb
```

구글·애플 로그인 설정은 Rails credentials를 사용합니다. 설정에서 계정을 삭제하면 세션·녹음·연습 기록이 삭제됩니다. 파일 삭제는 Active Job으로 처리합니다.
