usage() {
  cat <<'EOF'
usage: mrrp [name] [-h host] [-p port] [-rp port]

  name      subdomain to request     (default: random 4-hex)
  -h host   host to forward to       (default: localhost)
  -p port   port on that host        (default: 8000)
  -rp port  public port on mrrp.win  (default: 80)
EOF
}

die() {
  printf 'mrrp: %s\n\n' "$1" >&2
  usage >&2
  exit 1
}

name=""
host=localhost
port=8000
rport=80

while [ $# -gt 0 ]; do
  case $1 in
    -h | -p | -rp)
      [ $# -ge 2 ] || die "$1 needs a value"
      case $1 in
        -h) host=$2 ;;
        -p) port=$2 ;;
        -rp) rport=$2 ;;
      esac
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    -*) die "unknown flag $1" ;;
    *)
      name=$1
      shift
      ;;
  esac
done

[ -n "$name" ] || name=$(printf '%04x' $((RANDOM % 65536)))

exec ssh -p 2222 -R "$name:$rport:$host:$port" mrrp.win
