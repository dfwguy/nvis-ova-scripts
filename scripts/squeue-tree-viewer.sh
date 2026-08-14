#!/usr/bin/env bash
# nodetree - tree view of Slurm nodes: state, what's running on them,
#            and which pending jobs they are blocking.
#
# Requires: bash 4+, squeue, sinfo, scontrol
set -uo pipefail

PART=""; NODES=""; UFILT=""; ONLY_DOWN=0; ONLY_BUSY=0; SHOW_OTHER=1; GROUP=0; NOCOLOR=0; SHORT=0

usage() {
cat <<'EOF'
nodetree - what is running on each node, and what each node is blocking

Usage: nodetree [options]
  -p PART   limit to partition
  -w NODES  limit to nodes (slurm hostlist, e.g. ink50-dh01-j01-[10-40])
  -u USER   only count/show jobs for USER
  -d        only show problem nodes (down/drain/fail/maint/unknown)
  -b        only show nodes with running jobs
  -g        group nodes under their chassis/rack prefix
  -q        hide the "pending, not tied to a node" section
  -s        short script names (basename instead of full path)
  -n        no color
  -h        this help

Legend:  run = job running here      blk = pending job blocked by this node
EOF
}

while getopts "p:w:u:dbgqsnh" o; do
  case $o in
    p) PART=$OPTARG ;; w) NODES=$OPTARG ;; u) UFILT=$OPTARG ;;
    d) ONLY_DOWN=1 ;; b) ONLY_BUSY=1 ;; g) GROUP=1 ;; q) SHOW_OTHER=0 ;;
    s) SHORT=1 ;; n) NOCOLOR=1 ;; h) usage; exit 0 ;; *) usage; exit 1 ;;
  esac
done

if [[ $NOCOLOR -eq 1 || ! -t 1 ]]; then
  RST=; RED=; YEL=; GRN=; CYA=; DIM=; BLD=
else
  RST=$'\e[0m'; RED=$'\e[31m'; YEL=$'\e[33m'; GRN=$'\e[32m'
  CYA=$'\e[36m'; DIM=$'\e[2m'; BLD=$'\e[1m'
fi

shorten() {   # script path: full by default, basename with -s ; drop leading args
  local c=${1%%|*}
  [[ -z $c || $c == "(null)" ]] && { printf '%s' ""; return; }
  (( SHORT )) && c=${c##*/}
  printf '%s' "$c"
}
is_bad() { case "${1,,}" in *down*|*drain*|*drng*|*fail*|*err*|*unk*|*maint*|*inval*) return 0;; *) return 1;; esac; }
scolor() {
  case "${1,,}" in
    *down*|*fail*|*err*|*unk*|*inval*) printf '%s' "$RED" ;;
    *drain*|*drng*|*maint*|*resv*)     printf '%s' "$YEL" ;;
    *mix*|*alloc*|*comp*)              printf '%s' "$GRN" ;;
    *idle*)                            printf '%s' "$CYA" ;;
  esac
}

declare -A NSTATE NREASON ALLN RUN BLK RUNC BLKC HLC

# ---------- nodes ----------
sopts=(-h -N -o '%N|%T|%E')
[[ -n $PART  ]] && sopts+=(-p "$PART")
[[ -n $NODES ]] && sopts+=(-n "$NODES")
while IFS='|' read -r n st reason; do
  [[ -z $n ]] && continue
  NSTATE[$n]=$st; ALLN[$n]=1
  [[ $reason == "none" || $reason == "(null)" ]] && reason=""
  NREASON[$n]=$reason
done < <(sinfo "${sopts[@]}" 2>/dev/null)

expand_into() {   # $1 = hostlist -> echoes space separated hosts (memoized)
  local l=$1
  [[ -z $l || $l == "(null)" ]] && return
  if [[ -z ${HLC[$l]+x} ]]; then
    HLC[$l]=$(scontrol show hostnames "$l" 2>/dev/null | tr '\n' ' ')
  fi
  printf '%s' "${HLC[$l]}"
}

# ---------- running jobs ----------
qopts=(-h -t R -o '%i|%j|%u|%M|%N|%o')
[[ -n $PART  ]] && qopts+=(-p "$PART")
[[ -n $NODES ]] && qopts+=(-w "$NODES")
[[ -n $UFILT ]] && qopts+=(-u "$UFILT")
mapfile -t RLINES < <(squeue "${qopts[@]}" 2>/dev/null)
for line in "${RLINES[@]}"; do
  [[ -z $line ]] && continue
  IFS='|' read -r jid jname juser jtime jnodes jcmd <<<"$line"
  jcmd=$(shorten "$jcmd")
  for n in $(expand_into "$jnodes"); do
    RUN[$n]+="${jid}|${jname}|${juser}|${jtime}|${jcmd}"$'\n'
    RUNC[$n]=$(( ${RUNC[$n]:-0} + 1 ))
    ALLN[$n]=1
  done
done

# ---------- pending jobs ----------
popts=(-h -t PD -o '%i|%j|%u|%R|%o')
[[ -n $PART  ]] && popts+=(-p "$PART")
[[ -n $UFILT ]] && popts+=(-u "$UFILT")
mapfile -t PLINES < <(squeue "${popts[@]}" 2>/dev/null)
declare -A OTHERC OTHERJ
for line in "${PLINES[@]}"; do
  [[ -z $line ]] && continue
  IFS='|' read -r jid jname juser reason jcmd <<<"$line"
  jcmd=$(shorten "$jcmd")
  reason=${reason#(}; reason=${reason%)}
  short=${reason%%,*}
  if [[ $reason == *UnavailableNodes:* ]]; then
    hl=${reason##*UnavailableNodes:}; hl=${hl%\)}; hl=${hl%% }
    hosts=$(expand_into "$hl")
    if [[ -n ${hosts// /} ]]; then
      for n in $hosts; do
        BLK[$n]+="${jid}|${jname}|${juser}|${short}|${jcmd}"$'\n'
        BLKC[$n]=$(( ${BLKC[$n]:-0} + 1 ))
        [[ -z $NODES ]] && ALLN[$n]=1
      done
      continue
    fi
  fi
  OTHERC[$short]=$(( ${OTHERC[$short]:-0} + 1 ))
  [[ ${OTHERC[$short]} -le 4 ]] && OTHERJ[$short]+="$jid "
done

# ---------- render ----------
kids() {   # $1 = blob, $2 = tag, $3 = color, $4 = indent
  local blob=$1 tag=$2 col=$3 ind=$4 line a b c d e
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    IFS='|' read -r a b c d e <<<"$line"
    printf '%s%s %s%-3s%s %-9s %-16s %-9s %s%-16s %s%s\n' \
      "$ind" "$MID" "$col" "$tag" "$RST" "$a" "$b" "$c" "$DIM" "$d" "$e" "$RST"
  done <<<"$blob"
}

print_node() {
  local n=$1 ind=${2:-} st rs nr nb extra
  st=${NSTATE[$n]:-unknown}; rs=${NREASON[$n]:-}
  nr=${RUNC[$n]:-0}; nb=${BLKC[$n]:-0}
  (( ONLY_BUSY  && nr == 0 )) && return
  if (( ONLY_DOWN )); then is_bad "$st" || return; fi
  extra=""
  (( nr )) && extra+="  ${GRN}${nr} running${RST}"
  (( nb )) && extra+="  ${RED}blocking ${nb}${RST}"
  [[ -n $rs ]] && extra+="  ${DIM}\"${rs}\"${RST}"
  printf '%s%s%s%s  %s%s%s%s\n' "$ind" "$BLD" "$n" "$RST" "$(scolor "$st")" "$st" "$RST" "$extra"
  [[ -n ${RUN[$n]:-} ]] && kids "${RUN[$n]}" run "$GRN" "$ind"
  [[ -n ${BLK[$n]:-} ]] && kids "${BLK[$n]}" blk "$RED" "$ind"
}

MID='  |-'
mapfile -t SORTED < <(printf '%s\n' "${!ALLN[@]}" | sort -V)

printf '%s%s%s  %s\n' "$BLD" "NODE TREE" "$RST" "$(date '+%F %T')"

if (( GROUP )); then
  prev=""
  for n in "${SORTED[@]}"; do
    out=$(print_node "$n" "  ")
    [[ -z $out ]] && continue
    g=${n%-*}
    if [[ $g != "$prev" ]]; then printf '%s%s%s\n' "$CYA" "$g" "$RST"; prev=$g; fi
    printf '%s\n' "$out"
  done
else
  for n in "${SORTED[@]}"; do print_node "$n"; done
fi

if (( SHOW_OTHER )) && (( ${#OTHERC[@]} )); then
  printf '%spending, not tied to a specific node%s\n' "$BLD" "$RST"
  for r in "${!OTHERC[@]}"; do
    printf '  |- %-34s %s%4d jobs%s  %s%s%s\n' \
      "$r" "$YEL" "${OTHERC[$r]}" "$RST" "$DIM" "${OTHERJ[$r]:-}" "$RST"
  done
  printf '\n'
fi

tr=0; tb=0
for k in "${!RUNC[@]}"; do tr=$(( tr + RUNC[$k] )); done
for k in "${!BLKC[@]}"; do tb=$(( tb + BLKC[$k] )); done
bad=0; for n in "${SORTED[@]}"; do is_bad "${NSTATE[$n]:-}" && bad=$(( bad + 1 )); done
printf '%s%d nodes | %d bad | %d job-slots running | %d node-blocked pending%s\n' \
  "$DIM" "${#SORTED[@]}" "$bad" "$tr" "$tb" "$RST"
