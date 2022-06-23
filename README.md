# Speech Robot

```
tensil rtl -a ./arch/speech_robot.tarch -d 128 -s true -t vivado
```

```
tensil compile -a ./arch/speech_robot.tarch -m ./model/speech_commands.onnx -o "dense_1" -t model
```

```
tensil emulate -m ./model/speech_commands_onnx_speech_robot.tmodel -i ./model/speech_commands_input_25x8.csv -r 25
```