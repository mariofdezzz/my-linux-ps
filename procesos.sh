#!/bin/bash

die()
{
  echo "$0: $1" 1>&2
  exit 1
}

help()
{
  echo -e "$0 [-o atributos] [-u usuarios]\n
ATRIBUTOS ADMITIDOS
\tUID: Identificador del usuario que lanzó el proceso (RUID)
\tPID: Identificador del proceso
\tPPID: Identificador del proceso padre
\tTIME: Tiempo consumido de cpu (ejecución y en la cola de preparados)
\tSTART: Tiempo transcurrido desde el inicio del proceso
\tRSS: Tamaño de la memoria física usada en Kb
\tVSZ: Tamaño de la memoria virtual del proceso en Kb
\tPRI: Prioridad del proceso
\tSTAT: Estado del proceso
\tTTY: Nombre de la terminal a la que esta asociado el proceso \n"
  exit 0
}

# This function needs next variables and understands you know their use:
#   tmp_status
#   tmp_stat
#   header
#   res
add_output_line()
{
  for h in $header; do
    case $h in
      "UID" )
        uid_str="$(grep 'Uid' <<<"$tmp_status" | sed 's/\s\+/,/g' | cut -d ',' -f2 )"

        res="$res,$uid_str"
        ;;
      "PID" )
        pid_str="$(grep '^Pid:' <<<"$tmp_status" | grep -Eo '[0-9]+')"

        res="$res,$pid_str"
        ;;
      "PPID" )
        ppid_str="$(grep '^PPid:' <<<"$tmp_status" | grep -Eo '[0-9]+')"

        res="$res,$ppid_str"
        ;;
      "TIME" )
        # Data
        utime="$(cut -d ' ' -f14 <<<"$tmp_stat ")"
        stime="$(cut -d ' ' -f15 <<<"$tmp_stat ")"
        cutime="$(cut -d ' ' -f16 <<<"$tmp_stat ")"
        cstime="$(cut -d ' ' -f17 <<<"$tmp_stat ")"
        hertz="$(getconf CLK_TCK)"

        # Calculation
        total_time=$(( $utime + $stime + $cutime + $cstime ))
        total_time=$(( $total_time / $hertz ))

        # Result formatting
        hh=$(printf "%02d" "$(( $total_time / 3600 ))")
        mm=$(printf "%02d" "$(( ($total_time / 60) % 60 ))")
        ss=$(printf "%02d" "$(( $total_time % 60 ))")

        # Saving result
        res="$res,$hh:$mm:$ss"
        ;;
      "START" )
        # Data
        uptime="$(cut -d '.' -f1 </proc/uptime)"
        stat_time="$(cut -d ' ' -f22 <<<"$tmp_stat")"
        hertz="$(getconf CLK_TCK)"    # NO ESTABA !!

        # Calculation
        start_time=$(( $uptime - ( $stat_time / $hertz ) ))

        # Result formatting
        hh=$(printf "%02d" "$(( $start_time / 3600 ))")
        mm=$(printf "%02d" "$(( ($start_time / 60) % 60 ))")
        ss=$(printf "%02d" "$(( $start_time % 60 ))")

        # Saving result
        res="$res,$hh:$mm:$ss"
        ;;
      "RSS" )
        rss_str="$(grep '^VmRSS:' <<<"$tmp_status" | grep -Eo '[0-9]+')"

        # Correct empty value if exists
        if [[ $rss_str == "" ]]; then
          rss_str=0
        fi

        res="$res,$rss_str"
        ;;
      "VSZ" )
        vsz_bytes=$(cut -d ' ' -f23 <<<"$tmp_stat" )

        res="$res,$(( $vsz_bytes / 1024 ))"
        ;;
      "PRI" )
        pri_str="$( cut -d ' ' -f19 <<<"$tmp_stat " )"

        res="$res,$pri_str"
        ;;
      "STAT" )
        stat_str="$( grep '^State:' <<<"$tmp_status" | grep -Eio '\([a-z]*\)' | tr -d '()' )"

        res="$res,$stat_str"
        ;;
      "TTY" )
        tty_str="$( readlink -f "$i/fd/0" )"

        # String correction
        if [[ $(grep -E "pts|tty" <<<"$tty_str") == "" ]]; then
          tty_str="?"
        else
          # String beautify
          if [[ $(grep "pts" <<<"$tty_str") != "" ]]; then
            tty_str="pts${tty_str#*pts}"
          else
            tty_str="tty${tty_str#*tty}"
          fi
        fi

        res="$res,$tty_str"
        ;;
    esac
  done

  res="$res
"
}

# --- NO USERS FILTERING ---
# This function needs next variables and understands you know their use:
#   header
#   res
no_users_func()
{
  for i in $(find /proc -maxdepth 1 -type d -name "[0-9]*" 2>/dev/null); do

    # Check folder read permission
    [ ! -r $i ] && continue

    tmp_status="$(cat $i/status)"
    tmp_stat="$(cat $i/stat)"
    tmp_stat="${tmp_stat%(*}${tmp_stat#*)}"

    add_output_line
  done
}

# --- USERS FILTERING ---
# This function needs next variables and understands you know their use:
#   header
#   users
#   res
users_func()
{
  users_uid_list=""

  # GET UIDs
  for i in $users; do
    users_uid_list="$users_uid_list $(grep -E "^$i:" </etc/passwd | cut -d: -f3)"

  done

  # EXECUTION
  for i in $(find /proc -maxdepth 1 -type d -name "[0-9]*" 2>/dev/null); do

    # Check folder read permission
  	[ ! -r $i ] && continue


    tmp_status="$(cat $i/status)"
    tmp_stat="$(cat $i/stat)"
    tmp_stat="${tmp_stat%(*}${tmp_stat#*)}"

    uid_found=0
    actual_uid="$(grep 'Uid' <<<"$tmp_status" | tr "[:blank:]" "," | cut -d ',' -f2 )"
    for target_uid in $users_uid_list; do
      if (( $actual_uid == $target_uid )); then
        uid_found=1
        break
      fi
    done
    [[ $uid_found == 0 ]] && continue

    add_output_line
  done
}


# -------------------- PROGRAM START --------------------
res=""
users=""

# PROCESSING INPUT ARGUMENTS
while (( $# > 0 )); do
  [[ $1 == "-h" ]] && help
  [[ $1 == "--help" ]] && help

  if [[ $1 == "-o" ]]; then
    [[ $res != "" ]] && die "No se permiten argumentos repetidos."
    [[ $# == 1 ]] && die "Faltan argumentos para $1."

    res="$(tr '[:lower:]' '[:upper:]' <<<$2)
"
    shift

  elif [[ $1 == "-u" ]]; then
    [[ $users != "" ]] && die "No se permiten argumentos repetidos."
    [[ $# == 1 ]] && die "Faltan argumentos para $1."

    users="$(tr ',' ' ' <<<$2)"
    shift
  else
    die "Argumento $1 desconocido. Pruebe -h para más información."
  fi

  shift
done

# OPTION: -o
if [[ $res != "" ]]; then
  header="$(tr ',' ' ' <<<$res)"

  for i in $header; do
    case $i in
      "UID" )
        ;;
      "PID" )
        ;;
      "PPID" )
        ;;
      "TIME" )
        ;;
      "START" )
        ;;
      "RSS" )
        ;;
      "VSZ" )
        ;;
      "PRI" )
        ;;
      "STAT" )
        ;;
      "TTY" )
        ;;
      * )
        die "Parámetro $i no válido para la opción $1"
        ;;
    esac
  done
else
  res="UID,PID,PPID,TIME,START,RSS
"
  header="UID PID PPID TIME START RSS"
fi

# OPTION: -u  & result writting
if [[ "$users" != "" ]]; then
  users_func
else
  no_users_func
fi

# Print result table
column -ts "," -c 2 <<<"$res"
