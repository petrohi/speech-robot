# Speech Robot

```
tensil rtl -a ./arch/speech_robot.tarch -d 128 -s true -t build
```

```
tensil compile -a ./arch/speech_robot.tarch -m ./model/speech_commands_sglr.onnx -o "dense_1"
```