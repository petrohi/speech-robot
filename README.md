# Speech Robot

```
tensil rtl -a ./arch/speech_robot.tarch -d 128 -s true -t build
```

```
tensil compile -a ./arch/speech_robot.tarch -m ./model/speech_commands_sglr.onnx -o "dense_1"
```

```
tensil emulate -m ./speech_commands_sglr_onnx_speech_robot.tmodel -i ./model/speech_commands_sglr_input_10x8.csv -r 10
```