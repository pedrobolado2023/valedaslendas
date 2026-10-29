"""Configura o Supabase do Vale das Lendas (rodar UMA vez, no seu PC):
  - cria as tabelas e regras de supabase/schema.sql
  - liga o login por e-mail (sem confirmação por enquanto) e o login anônimo
  - grava res://supabase.cfg com a URL e a chave pública (anon), que o jogo usa

Uso (PowerShell):
  $env:SUPABASE_TOKEN = "sbp_..."   # token de acesso (Account > Access Tokens)
  python tools/supabase_setup.py
O token não é salvo em lugar nenhum. Depois de configurar, pode revogar o token no painel."""
import json
import os
import urllib.request

REF = "vvgufliyrwdxwwvyosho"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOKEN = os.environ.get("SUPABASE_TOKEN", "")
API = "https://api.supabase.com/v1/projects/" + REF


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": "Bearer " + TOKEN, "Content-Type": "application/json",
                                          "User-Agent": "vale-das-lendas-setup"})
    with urllib.request.urlopen(req) as r:
        txt = r.read().decode()
        return json.loads(txt) if txt else {}


def main():
    if not TOKEN:
        raise SystemExit("Defina a variável SUPABASE_TOKEN antes (veja o topo do arquivo).")
    p = call("GET", "")
    print("Projeto:", p.get("name"), "-", p.get("status"))
    sql = open(os.path.join(ROOT, "supabase", "schema.sql"), encoding="utf-8").read()
    call("POST", "/database/query", {"query": sql})
    print("Tabelas e regras criadas.")
    call("PATCH", "/config/auth", {"external_email_enabled": True, "mailer_autoconfirm": True,
                                   "external_anonymous_users_enabled": True})
    print("Login por e-mail e anônimo ligados.")
    keys = call("GET", "/api-keys")
    anon = next(k["api_key"] for k in keys if k.get("name") == "anon")
    with open(os.path.join(ROOT, "supabase.cfg"), "w", encoding="utf-8") as f:
        f.write('[supabase]\nurl="https://%s.supabase.co"\nanon_key="%s"\n' % (REF, anon))
    print("supabase.cfg gravado. Pronto!")


main()
