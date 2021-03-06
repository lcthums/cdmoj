#!/bin/bash
#This file is part of CD-MOJ.
#
#CD-MOJ is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#CD-MOJ is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with CD-MOJ.  If not, see <http://www.gnu.org/licenses/>.

source common.sh
AGORA=$(date +%s)


#limpar caminho, exemplo
#www.brunoribas.com.br/~ribas/moj/cgi-bin/contest.sh/contest-teste/oi
#vira 'contest-teste/oi'
CAMINHO="$PATH_INFO"
#TESTE="$0"
#CAMINHO="$(sed -e 's#.*/contest.sh/##' <<< "$CAMINHO")"

#contest é a base do caminho
CONTEST="$(cut -d'/' -f2 <<< "$CAMINHO")"
CONTEST="${CONTEST// }"

if [[ "x$CONTEST" == "x" ]] || [[ ! -d "$CONTESTSDIR/$CONTEST" ]] || 
  [[ "$CONTEST" == "admin" ]]; then
  tela-erro
  exit 0
fi

source $CONTESTSDIR/$CONTEST/conf
if (verifica-login $CONTEST| grep -q Sim) && (is-admin |grep -q Sim); then
  incontest-cabecalho-html $CONTEST
else
  cabecalho-html
fi
printf "<h1>Estatísticas de \"<em>$CONTEST_NAME</em>\"</h1>\n"

printf "<ul><li>Início: $(date --date=@$CONTEST_START)</li>"
printf "<li>Término:  $(date --date=@$CONTEST_END)</li>"

if (( AGORA < CONTEST_END )) && (is-admin | grep -q Nao); then
  printf "<p>O Contest ainda <b>NÃO</b> encerrou.</p>\n"
  if [[ "$PARTIALSTATISTIC" == "1" ]]; then
    printf "<p> As estatísticas disponibilizadas aqui são PARCIAIS e são "
    printf "atualizadas a cada submissão</p>\n"
  else
    printf "<p> Este contest NÃO permite estatísticas parciais, aguarde!</p>\n"
    cat ../footer.html
    exit 0
  fi
fi

#mostrar exercicios
printf "<br/><br/><h2>Problems</h2>\n"
TOTPROBS=${#PROBS[@]}
#((TOTPROBS=TOTPROBS/5))
LINHA=1
echo "<table border=1><tr><th>ID</th><th>Full Name</th><th>Local Description</th><th>OJ Link</th></tr>"
for ((i=0;i<TOTPROBS;i+=5)); do
  BGCOLOR=
  if (( LINHA%2 == 0 )); then
    BGCOLOR="bgcolor='#00EEEE'"
  fi
  printf "<tr $BGCOLOR><td>${PROBS[$((i+3))]}</td><td>${PROBS[$((i+2))]}</td>"
  LINK="${PROBS[$((i+4))]}"

  if [[ "$LINK" =~ "http://" ]]; then
    printf "<td><a href=\"$LINK\" target=\"_blank\">desc</a></td>"
  elif [[ "$LINK" != "none" && "$LINK" != "site" && "$LINK" != "sitepdf" ]]; then
    printf "<td><a href=\"$BASEURL/contests/$CONTEST_ID/$LINK\" target=\"_blank\">desc</a></td>"
  else
    printf "<td> - - </td>"
  fi
  LINK="$(link-prob-${PROBS[i]} ${PROBS[$((i+1))]})"
  printf "<td> <a href='$LINK'>${PROBS[$((i+1))]}</td></tr>\n"
  ((LINHA++))
done
echo "</table>"

#Gerar Tabela com pontuacao
LINHA=0
printf "<br/><br/><h2>Runs by Problems</h2>\n"
echo "<table border=1>"
echo "<tr><th>#</th><th>Total</th><th>Accepted</th></tr>"
for ((i=0;i<TOTPROBS;i+=5)); do
  ID=$i
  TOTALRUNS="$(cut -d: -f3 $CONTESTSDIR/$CONTEST/controle/history|grep -c "^$ID$")"
  TOTALAC="$(cut -d: -f3,5 $CONTESTSDIR/$CONTEST/controle/history|grep -c "^$ID:Accepted$")"
  ACPER=""
  if ((TOTALRUNS > 0)); then
    ACPER="($((TOTALAC*100/TOTALRUNS))%%)"
  fi
  BGCOLOR=
  if (( LINHA%2 == 0 )); then
    BGCOLOR="bgcolor='#00EEEE'"
  fi
  printf "<tr $BGCOLOR><td>${PROBS[$((i+3))]}</td><td>$TOTALRUNS</td><td>$TOTALAC ${ACPER}</td></tr>"
  ((LINHA++))
done
echo "</table>"

printf "<br/><br/><h2>Runs by User and Problem</h2>\n"
echo "<table border=1>"
echo "<tr><th>Users x Problems</th>"
for ((i=0;i<TOTPROBS;i+=5)); do
  printf "<th>${PROBS[$((i+3))]}</th>"
done
echo "<th>Total</th><th>Accepted</th></tr>"

for LOGIN in $CONTESTSDIR/$CONTEST/controle/*.d; do
  LOGINN="$(basename $LOGIN .d)"
  if grep -q "\.admin$" <<< "$LOGINN"; then
    continue
  fi
  NOME=$(grep "^$LOGINN:" $CONTESTSDIR/$CONTEST/passwd |cut -d':' -f3)
  TOTALRUNS="$(cut -d: -f2 $CONTESTSDIR/$CONTEST/controle/history|grep -c "^$LOGINN$")"
  AC=0
  printf "<td>$NOME</td>"
  for ((i=0;i<TOTPROBS;i+=5)); do
    JAACERTOU=0
    TENTATIVAS=0
    source $LOGIN/$i 2>/dev/null
    COR=lightgreen
    if (( JAACERTOU == 0 ));then
      COR=white
    else
      ((AC++))
    fi

    if (( TENTATIVAS != 0 )) && ((TOTALRUNS!=0)); then
      TENTATIVAS="$TENTATIVAS ( $((TENTATIVAS*100/TOTALRUNS))%%)"
    fi
    printf "<td bgcolor=$COR>$TENTATIVAS</td>"
  done

  ACO=$AC
  if ((AC!=0)); then
    AC="$AC ( $((AC*100/TOTALRUNS))%)"
  fi
  echo "<td>$TOTALRUNS</td><td>$AC</td></tr>:$ACO"
done|sort -n -r -t':' -k2|cut -d: -f1
echo "</table>"

CONT=1
printf "<br/><br/><h2>Runs</h2>\n"
echo "<table border=1 width=100%>"
printf "<tr><th>#</th><th>User</th><th>Time</th><th>Problem</th>"
printf "<th>Language</th><th>Local Time</th><th>Answer</th></tr>\n"
sort -t':' -n $CONTESTSDIR/$CONTEST/controle/history|
while read LINE; do
  TEMPO="$(cut -d: -f1 <<< "$LINE")"
  ((TMPOMIN= TEMPO/60 ))
  ((LOCALTIME= CONTEST_START + TEMPO))
  LOCALTIME="$(date --date=@$LOCALTIME)"
  LOGIN="$(cut -d: -f2 <<< "$LINE")"
  PROBID="$(cut -d: -f3 <<< "$LINE")"
  LING="$(cut -d: -f4 <<< "$LINE")"
  RESP="$(cut -d: -f5 <<< "$LINE")"
  NOME=$(grep "^$LOGIN:" $CONTESTSDIR/$CONTEST/passwd |cut -d':' -f3)
  BGCOLOR=
  if (( CONT%2 == 0 )); then
    BGCOLOR="bgcolor='#00EEEE'"
  fi
  printf "<tr $BGCOLOR><td>$CONT</td><td>$NOME</td><td>$TMPOMIN</td>"
  printf "<td>${PROBS[$((PROBID+3))]}</td><td>$LING</td>"
  printf "<td>$LOCALTIME</td><td>$RESP</td></tr>"

  ((CONT++))
done
echo "</table>"


if (verifica-login $CONTEST| grep -q Sim) && (is-admin |grep -q Sim); then
  incontest-footer
else
  cat ../footer.html
fi
