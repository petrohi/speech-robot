# Speech Robot

```
tensil rtl -a ./arch/speech_commands.tarch -d 128 -s true -t build
```

```
tensil compile -a ./arch/speech_commands.tarch -m ./model/speech_commands.onnx -o "dense_3"
```