import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return respond({ error: 'Method not allowed' }, 405);

  const authorization = request.headers.get('Authorization');
  const token = authorization?.replace(/^Bearer\s+/i, '');
  if (!token) return respond({ error: 'Authentication required' }, 401);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return respond({ error: 'Server configuration is incomplete' }, 500);
  }

  const callerClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await callerClient.auth.getUser(token);
  if (authError || !authData.user) return respond({ error: 'Invalid session' }, 401);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: callerProfile, error: profileError } = await admin
    .from('users')
    .select('role, active')
    .eq('id', authData.user.id)
    .maybeSingle();
  if (profileError) return respond({ error: 'Could not verify administrator profile' }, 500);
  if (callerProfile?.role !== 'admin' || callerProfile.active !== true) {
    return respond({ error: 'An active administrator account is required' }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return respond({ error: 'Request body must be valid JSON' }, 400);
  }

  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  const role = typeof body.role === 'string' ? body.role : '';
  const rhuId = typeof body.rhu_id === 'string' && body.rhu_id ? body.rhu_id : null;
  const facilityId = typeof body.facility_id === 'string' && body.facility_id ? body.facility_id : null;
  const barangayId = typeof body.barangay_id === 'string' && body.barangay_id ? body.barangay_id : null;

  if (!email.includes('@') || !name || !role) {
    return respond({ error: 'A valid email, name, and role are required' }, 400);
  }

  const { data: roleRow, error: roleError } = await admin
    .from('roles')
    .select('id, requires_rhu, requires_facility, requires_barangay, is_assignable')
    .eq('id', role)
    .maybeSingle();
  if (roleError) return respond({ error: 'Could not verify the requested role' }, 500);
  if (!roleRow?.is_assignable) return respond({ error: 'That role cannot be assigned to a new account' }, 400);
  if (roleRow.requires_rhu && !rhuId) return respond({ error: 'An RHU assignment is required for this role' }, 400);
  if (roleRow.requires_facility && !facilityId) return respond({ error: 'A facility assignment is required for this role' }, 400);
  if (roleRow.requires_barangay && !barangayId) return respond({ error: 'A barangay assignment is required for this role' }, 400);

  const { data: invitation, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
    data: { full_name: name },
    redirectTo: 'salcedo-dengue-watch://auth-callback/',
  });
  if (inviteError || !invitation.user) {
    return respond({ error: inviteError?.message ?? 'Invitation could not be created' }, 400);
  }

  // The Auth trigger creates an inactive pending profile first. Upsert assigns
  // the requested role and scope but keeps the account inactive for admin
  // review after the invitee confirms their email.
  const { error: updateError } = await admin.from('users').upsert({
    id: invitation.user.id,
    email,
    name,
    role,
    rhu_id: roleRow.requires_rhu ? rhuId : null,
    facility_id: roleRow.requires_facility ? facilityId : null,
    barangay_id: roleRow.requires_barangay ? barangayId : null,
    active: false,
    password_setup_required: true,
    created_by: authData.user.id,
  }, { onConflict: 'id' });

  if (updateError) {
    // The Auth identity remains pending/inactive via the trigger so an admin
    // can safely diagnose and retry without creating an active unscoped user.
    return respond({
      error: 'Invitation was created, but the profile could not be assigned. The account remains inactive.',
      details: updateError.message,
    }, 500);
  }

  return respond({ user_id: invitation.user.id, invited: true });
});
