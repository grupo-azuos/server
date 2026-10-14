// Funcao de exemplo. Teste com:
//   curl http://localhost:8000/functions/v1/hello -H "apikey: <ANON_KEY>"
Deno.serve((req: Request) => {
  return new Response(
    JSON.stringify({
      ok: true,
      message: 'edge function rodando no servidor',
      method: req.method,
      at: new Date().toISOString(),
    }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
