# Speech Robot

```
./mill rtl.run -a ./arch/artya7100t.tarch -d 128 -s true -t build
```

```
./mill compiler.run -a ./arch/artya7100t.tarch -m ./models/speech_commands.onnx -o "dense_3"
```