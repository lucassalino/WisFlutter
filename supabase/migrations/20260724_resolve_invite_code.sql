-- Adds a minimal, additive RPC so the native app can resolve an invite
-- code to an organization id *before* the user is a member — RLS on
-- `organizations` ("members can read") otherwise blocks that lookup for
-- non-members, since knowing the code is exactly the credential that
-- proves the right to join.
--
-- Mirrors the pattern already used by ServiceFlow's is_org_member/
-- is_org_admin helpers (018_security_hardening.sql): SECURITY DEFINER,
-- fixed search_path, EXECUTE revoked from public/anon and granted only
-- to `authenticated`. Returns only the org id — never the full row.
--
-- Does not touch any existing table, policy, or behaviour used by the
-- ServiceFlow web app; purely additive.

create or replace function public.resolve_invite_code(p_code text)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select id from public.organizations where invite_code = upper(p_code);
$$;

revoke all on function public.resolve_invite_code(text) from public, anon, authenticated;
grant execute on function public.resolve_invite_code(text) to authenticated;
