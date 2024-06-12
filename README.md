# book_time_tracker

책 읽은 시간을 기록하기 위한 간단한 앱입니다.
2024 봄학기 딥러닝 Term Project를 위해 구현하였습니다.

먼저 Roboflow를 활용해 opened/closed 이진 분류 모델을 학습시켰습니다.
이때 학습된 모델의 inference를 실행해, (서버) 파이썬을 먼저 실행하여 서버를 통해 예측 결과를 수신하여,
(클라이언트) Flutter App에서 예측 결과와 시간을 송신하는 구조입니다. 
