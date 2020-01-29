<h1 align="center"> My Linux ps 🖥️</h1>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0-brightgreen" />
</p>

## 📝 Description

> Reduced version of ps in bash script. <br>This is a small proyect and only speaks Spanish.

## 🚀 Usage
Here it is all the needed information. You can get it too by using ```-h``` or ```--help``` options.
```sh
./procesos.sh [-o atributos] [-u usuarios]

ATRIBUTOS ADMITIDOS
        * UID: Identificador del usuario que lanzó el proceso (RUID)
        * PID: Identificador del proceso
        * PPID: Identificador del proceso padre
        * TIME: Tiempo consumido de cpu (ejecución y en la cola de preparados)
        * START: Tiempo transcurrido desde el inicio del proceso
        * RSS: Tamaño de la memoria física usada en Kb
        * VSZ: Tamaño de la memoria virtual del proceso en Kb
        * PRI: Prioridad del proceso
        * STAT: Estado del proceso
        * TTY: Nombre de la terminal a la que esta asociado el proceso
```
