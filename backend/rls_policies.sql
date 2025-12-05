-- LearnLynk Tech Test - Task 2: RLS Policies on leads

-- Drop existing policies if any
DROP POLICY IF EXISTS leads_select_policy ON leads;
DROP POLICY IF EXISTS leads_insert_policy ON leads;

alter table public.leads enable row level security;
-- You can use: current_setting('request.jwt.claims', true)::jsonb

-- TODO: write a policy so:
-- - counselors see leads where they are owner_id OR in one of their teams
-- - admins can see all leads of their tenant
create policy "leads_select_policy"
on public.leads
for select
using USING (
        -- Match tenant_id from JWT
        tenant_id = auth.jwt() ->> 'tenant_id'::text
        AND (
            -- Admins can see all leads in their tenant
            (auth.jwt() ->> 'role'::text = 'admin')
            OR
            -- Counselors can see leads they own
            (
                auth.jwt() ->> 'role'::text = 'counselor'
                AND owner_id = (auth.jwt() ->> 'user_id'::text)::uuid
            )
            OR
            -- Counselors can see leads assigned to teams they belong to
            (
                auth.jwt() ->> 'role'::text = 'counselor'
                AND EXISTS (
                    SELECT 1
                    FROM user_teams ut
                    JOIN teams t ON ut.team_id = t.id
                    WHERE ut.user_id = (auth.jwt() ->> 'user_id'::text)::uuid
                    AND t.id = leads.team_id
                    AND t.tenant_id = leads.tenant_id
                )
            )
        )
    );

-- TODO: add INSERT policy that:
-- INSERT Policy: Counselors and admins can add leads under their tenant
CREATE POLICY leads_insert_policy ON leads
    FOR INSERT
    WITH CHECK (
        -- User must be from the same tenant
        tenant_id = auth.jwt() ->> 'tenant_id'::text
        AND
        -- User must be either admin or counselor
        (
            auth.jwt() ->> 'role'::text IN ('admin', 'counselor')
        )
        AND
        -- For counselors, they can only create leads where they are the owner
        (
            auth.jwt() ->> 'role'::text = 'admin'
            OR
            (
                auth.jwt() ->> 'role'::text = 'counselor'
                AND owner_id = (auth.jwt() ->> 'user_id'::text)::uuid
            )
        )
    );

-- UPDATE Policy: Users can update leads they have access to
CREATE POLICY leads_update_policy ON leads
    FOR UPDATE
    USING (
        tenant_id = auth.jwt() ->> 'tenant_id'::text
        AND (
            (auth.jwt() ->> 'role'::text = 'admin')
            OR
            (
                auth.jwt() ->> 'role'::text = 'counselor'
                AND owner_id = (auth.jwt() ->> 'user_id'::text)::uuid
            )
            OR
            (
                auth.jwt() ->> 'role'::text = 'counselor'
                AND EXISTS (
                    SELECT 1
                    FROM user_teams ut
                    JOIN teams t ON ut.team_id = t.id
                    WHERE ut.user_id = (auth.jwt() ->> 'user_id'::text)::uuid
                    AND t.id = leads.team_id
                )
            )
        )
    )
    WITH CHECK (
        tenant_id = auth.jwt() ->> 'tenant_id'::text
    );

-- DELETE Policy: Only admins can delete leads
CREATE POLICY leads_delete_policy ON leads
    FOR DELETE
    USING (
        tenant_id = auth.jwt() ->> 'tenant_id'::text
        AND auth.jwt() ->> 'role'::text = 'admin'
    );

-- Optional: Add RLS to applications and tasks tables as well
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Applications policies (inherit from leads)
CREATE POLICY applications_select_policy ON applications
    FOR SELECT
    USING (
        tenant_id = auth.jwt() ->> 'tenant_id'::text
        AND EXISTS (
            SELECT 1 FROM leads
            WHERE leads.id = applications.lead_id
        )
    );

CREATE POLICY applications_insert_policy ON applications
    FOR INSERT
    WITH CHECK (
        tenant_id = auth.jwt() ->> 'tenant_id'::text
        AND auth.jwt() ->> 'role'::text IN ('admin', 'counselor')
    );

-- Tasks policies (inherit from applications)
CREATE POLICY tasks_select_policy ON tasks
    FOR SELECT
    USING (
        tenant_id = auth.jwt() ->> 'tenant_id'::text
        AND EXISTS (
            SELECT 1 FROM applications a
            JOIN leads l ON l.id = a.lead_id
            WHERE a.id = tasks.application_id
        )
    );

CREATE POLICY tasks_all_policy ON tasks
    FOR ALL
    USING (
        tenant_id = auth.jwt() ->> 'tenant_id'::text
    )
    WITH CHECK (
        tenant_id = auth.jwt() ->> 'tenant_id'::text
    );

-- Comments for documentation
COMMENT ON POLICY leads_select_policy ON leads IS 'Counselors see owned leads or team leads; Admins see all tenant leads';
COMMENT ON POLICY leads_insert_policy ON leads IS 'Counselors and admins can create leads under their tenant';
