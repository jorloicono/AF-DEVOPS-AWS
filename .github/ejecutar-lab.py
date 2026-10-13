"""Extrae los bloques ```bash de un laboratorio y los concatena en un único script."""
import re, sys
md = open(sys.argv[1], encoding="utf-8").read()
bloques = re.findall(r"```bash\n(.*?)```", md, flags=re.S)
print("set +e")
for i, b in enumerate(bloques, 1):
    print(f'echo; echo "################ BLOQUE {i} ################"')
    print(b)
