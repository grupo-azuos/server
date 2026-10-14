// Main service do Edge Runtime: recebe TODA requisicao em /functions/v1/<nome>
// e despacha para a pasta volumes/functions/<nome>/index.ts.
// Para criar uma funcao nova basta criar a pasta -- nao precisa reiniciar nada.
import { STATUS_CODE } from 'jsr:@std/http/status'

Deno.serve(async (req: Request) => {
  const url = new URL(req.url)
  const { pathname } = url
  const functionName = pathname.split('/').filter(Boolean)[0]

  if (!functionName) {
    return new Response(
      JSON.stringify({ message: 'edge runtime do supabase no ar. use /functions/v1/hello' }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  }

  const servicePath = `/home/deno/functions/${functionName}`

  try {
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath,
      memoryLimitMb: 150,
      workerTimeoutMs: 5 * 60 * 1000,
      noModuleCache: false,
      envVars: Object.entries(Deno.env.toObject()),
    })
    return await worker.fetch(req)
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e), function: functionName }),
      {
        status: STATUS_CODE.InternalServerError,
        headers: { 'Content-Type': 'application/json' },
      },
    )
  }
})
