# Controle online de licença — 3105

## Fluxo do aplicativo

A câmera traseira abre normalmente. O acesso à tela original acontece quando o usuário toca no botão branco do obturador. Nesse momento, o app consulta o servidor online. Se não existir uma licença ativa para aquele aparelho, aparece a tela para inserir uma key.

As keys disponíveis são de 1, 7 e 30 dias. A contagem começa na primeira ativação. Depois de ativada, a key fica vinculada ao identificador persistente salvo no Keychain do iOS e não pode ser usada em outro aparelho.

## Servidor

Painel de administração e API:

`https://3000-iz7my112fal5cha1lykwv-f382c1ca.us1.manus.computer`

A API usada pelo app é:

- `GET /api/trpc/license.verify`
- `POST /api/trpc/license.activate?batch=1`

O app envia somente a key e um identificador técnico do aparelho. A key é armazenada no servidor apenas como hash SHA-256; o texto completo é mostrado uma única vez ao administrador no momento da criação.

## Gerar uma key

1. Abra o endereço do servidor em um navegador.
2. Entre com a conta administradora.
3. Clique em **1 dia**, **7 dias** ou **30 dias**.
4. Copie a key exibida imediatamente e entregue-a ao usuário.
5. A key será vinculada ao primeiro aparelho que a ativar.

O painel permite visualizar a data de ativação, expiração e aparelho vinculado, além de revogar uma key.

## Observação de produção

O endereço acima é o endereço público atual do projeto WebDev. Se o serviço for migrado para outro domínio, atualize a constante `baseURL` em `ThreeOneOSFive/ContentView.swift` e gere uma nova IPA.
