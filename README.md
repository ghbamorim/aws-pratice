# aws-pratice

Laboratório de desenvolvimento e DevOps com **FastAPI**, **React + Vite**, **PostgreSQL** e **Docker**, com evolução planejada para CI/CD e deploy na AWS.

> **Status:** configuração do ambiente local em andamento. As instruções de frontend/Nginx abaixo descrevem a configuração-alvo discutida; confirme que os arquivos correspondentes foram criados antes de executar o modo completo.

## Arquitetura

- **API:** FastAPI em imagem Docker própria, porta interna `8000`.
- **Frontend:** React compilado com Vite, servido por **Nginx** em imagem própria.
- **Banco:** PostgreSQL 16 em container no desenvolvimento; banco gerenciado poderá ser adotado na AWS.
- **Roteamento:** navegador acessa o frontend; chamadas relativas a `/api` são encaminhadas à API.
- **S3:** integração prevista para anexos. Não é necessário usar LocalStack.

Manter **uma imagem para API e outra para frontend** permite versionar, implantar e reverter cada componente independentemente.

## Pré-requisitos

- Docker Desktop com Docker Compose
- Node.js e npm, para executar o frontend fora do Docker
- Python e dependências do backend, para executar a API fora do Docker

## Modos de execução

### 1. Ambiente completo no Docker

Após adicionar `frontend/Dockerfile`, `frontend/nginx.conf` e o serviço `frontend` ao `compose.yaml`:

```powershell
docker compose up -d --build
```

Acesse **http://localhost:8080**. O Nginx serve o React e encaminha `/api` para `http://api:8000` na rede Docker.

O `compose.yaml` deve conter os serviços `db`, `api` e `frontend`, com publicação de portas somente no loopback local:

- PostgreSQL: `127.0.0.1:5432:5432`
- FastAPI: `127.0.0.1:8001:8000`
- Nginx: `127.0.0.1:8080:80`

### 2. Somente o banco no Docker

```powershell
docker compose up -d db
```

Execute a API Python localmente, configurando:

```text
DATABASE_URL=postgresql+psycopg://app:app@localhost:5432/app
```

A API precisa estar disponível na porta **8001** para o proxy padrão do Vite. Inicie o backend com o comando apropriado ao projeto e depois, no diretório `frontend`:

```powershell
npm install
npm run dev
```

Acesse **http://localhost:5173**.

**Atenção:** dentro da rede Docker o hostname do banco é `db`; no Windows é `localhost`. O banco precisa publicar a porta `127.0.0.1:5432:5432` no Compose para este modo funcionar.

## Configuração do frontend

### `frontend/vite.config.ts`

O proxy abaixo é usado **apenas pelo servidor de desenvolvimento do Vite**, não pelo build de produção:

```ts
import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  return {
    plugins: [react()],
    server: {
      host: "127.0.0.1",
      port: 5173,
      strictPort: true,
      proxy: {
        "/api": {
          target: env.API_PROXY_TARGET || "http://localhost:8001",
          changeOrigin: true,
        },
      },
    },
  };
});
```

O frontend deve chamar caminhos relativos como `fetch("/api/...")`, sem fixar o host da API no código. Se o Vite for executado em outro container, ajuste `API_PROXY_TARGET` para o endereço acessível naquele ambiente.

### `frontend/Dockerfile` (a criar)

```dockerfile
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:stable-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
```

### `frontend/nginx.conf` (a criar)

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location /api/ {
        proxy_pass http://api:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

A ausência de barra final em `proxy_pass http://api:8000` preserva o prefixo `/api`. Essa configuração pressupõe que a API exponha rotas nesse prefixo.

### `frontend/.dockerignore` (a criar)

```text
node_modules
dist
.git
.env*
```

## Compose: alterações pendentes

O Compose inicial contém `db` e `api`. Para suportar os dois modos acima, é necessário:

1. Publicar a porta do banco com `127.0.0.1:5432:5432`.
2. Manter a API conectada ao banco pelo endereço `db:5432`.
3. Adicionar o serviço `frontend`, com `build: ./frontend`, porta `127.0.0.1:8080:80` e dependência da API.
4. Testar `docker compose up -d --build` e `docker compose up -d db`.

As credenciais `app/app` são **exclusivas do laboratório local**. Não devem ser usadas em produção.

## Roadmap

- [ ] Concluir e testar os dois modos de execução local
- [ ] Configurar testes, lint e build no GitHub Actions (CI)
- [ ] Provisionar recursos AWS com Terraform
- [ ] Publicar imagens versionadas em registry
- [ ] Configurar deploy acionado manualmente por release
- [ ] Adicionar health checks e rollback
- [ ] Validar custos, permissões e observabilidade

**Região AWS de referência:** `us-east-2` (Ohio). O objetivo é manter custos baixos e evitar criar recursos AWS antes de validar o ambiente local.

## Manutenção da documentação

Atualizar este README a cada etapa implementada e testada, movendo itens concluídos no roadmap e registrando os comandos efetivamente usados.
