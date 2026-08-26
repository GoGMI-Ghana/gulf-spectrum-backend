// Paystack webhook handler — Supabase Edge Function (Deno runtime).
//
// Not connected to a real Paystack account yet. To go live:
//   1. Create a Paystack account and get the secret key from Settings -> API Keys & Webhooks.
//   2. Set it as a Supabase secret:  supabase secrets set PAYSTACK_SECRET_KEY=sk_...
//   3. Deploy:  supabase functions deploy paystack-webhook
//   4. In the Paystack dashboard, set the webhook URL to:
//      https://<project-ref>.supabase.co/functions/v1/paystack-webhook
//   5. When starting a checkout from the frontend, pass metadata of the shape
//      { type: 'donation' | 'membership', record_id: '<uuid>' } so this handler
//      knows which row to update — see the SupportBox / JoinForm components in
//      the frontend repo for where that checkout call would be made.
//
// Until then, this function will 401 on every request (no secret configured)
// and nothing calls it.

import { createClient } from 'jsr:@supabase/supabase-js@2'

interface PaystackEvent {
  event: string
  data: {
    reference: string
    status: string
    amount: number // minor units (pesewas/kobo), matches amount_minor_units
    currency: string
    metadata?: {
      type?: 'donation' | 'membership'
      record_id?: string
    }
  }
}

async function verifySignature(rawBody: string, signature: string | null, secret: string): Promise<boolean> {
  if (!signature) return false

  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-512' },
    false,
    ['sign']
  )
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(rawBody))
  const computed = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')

  // Constant-time-ish comparison — signature strings are the same fixed
  // length (128 hex chars for SHA-512), so a simple loop is fine here.
  if (computed.length !== signature.length) return false
  let diff = 0
  for (let i = 0; i < computed.length; i++) {
    diff |= computed.charCodeAt(i) ^ signature.charCodeAt(i)
  }
  return diff === 0
}

Deno.serve(async (req: Request) => {
  const secret = Deno.env.get('PAYSTACK_SECRET_KEY')
  if (!secret) {
    return new Response('Paystack secret key not configured', { status: 401 })
  }

  const rawBody = await req.text()
  const signature = req.headers.get('x-paystack-signature')

  if (!(await verifySignature(rawBody, signature, secret))) {
    return new Response('Invalid signature', { status: 401 })
  }

  const event = JSON.parse(rawBody) as PaystackEvent

  if (event.event !== 'charge.success') {
    // Acknowledge and ignore anything we don't handle yet (refunds,
    // disputes, subscription events, ...).
    return new Response('ok', { status: 200 })
  }

  const { reference, metadata } = event.data
  if (!metadata?.type || !metadata?.record_id) {
    console.error('charge.success webhook missing metadata.type/record_id', reference)
    return new Response('ok', { status: 200 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const table = metadata.type === 'donation' ? 'donations' : 'memberships'
  const { error } = await supabase
    .from(table)
    .update({ status: 'completed', payment_provider: 'paystack', payment_reference: reference })
    .eq('id', metadata.record_id)

  if (error) {
    console.error(`Failed to mark ${table} ${metadata.record_id} as completed`, error)
    return new Response('Database update failed', { status: 500 })
  }

  return new Response('ok', { status: 200 })
})
