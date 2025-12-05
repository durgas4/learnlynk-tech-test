-- LearnLynk Tech Test - Task 1: Schema
-- Fill in the definitions for leads, applications, tasks as per README.

-- Drop tables if they exist (for clean setup)
DROP TABLE IF EXISTS tasks CASCADE;
DROP TABLE IF EXISTS applications CASCADE;
DROP TABLE IF EXISTS leads CASCADE;

create extension if not exists "pgcrypto";

-- Leads table
create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  owner_id uuid not null,
  email text,
  phone text,
  full_name text,
  stage text not null default 'new',
  source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- TODO: add useful indexes for leads:
-- - by tenant_id, owner_id, stage, created_at


-- Applications table
create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  lead_id uuid not null references public.leads(id) on delete cascade,
  program_id uuid,
  intake_id uuid,
  stage text not null default 'inquiry',
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- TODO: add useful indexes for applications:
-- - by tenant_id, lead_id, stage


-- Tasks table
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  application_id uuid not null references public.applications(id) on delete cascade,
  title text,
  type text not null,
  status text not null default 'open',
  due_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Indexes for leads table
CREATE INDEX idx_leads_tenant_id ON leads(tenant_id);
CREATE INDEX idx_leads_owner_id ON leads(owner_id);
CREATE INDEX idx_leads_stage ON leads(stage);
CREATE INDEX idx_leads_tenant_owner ON leads(tenant_id, owner_id);
CREATE INDEX idx_leads_tenant_stage ON leads(tenant_id, stage);

-- Indexes for applications table
CREATE INDEX idx_applications_tenant_id ON applications(tenant_id);
CREATE INDEX idx_applications_lead_id ON applications(lead_id);
CREATE INDEX idx_applications_tenant_lead ON applications(tenant_id, lead_id);
CREATE INDEX idx_applications_status ON applications(status);

-- Indexes for tasks table
CREATE INDEX idx_tasks_tenant_id ON tasks(tenant_id);
CREATE INDEX idx_tasks_due_at ON tasks(due_at);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_application_id ON tasks(application_id);
CREATE INDEX idx_tasks_tenant_due_status ON tasks(tenant_id, due_at, status);
CREATE INDEX idx_tasks_due_at_date ON tasks(DATE(due_at)) WHERE status != 'completed';

-- Trigger function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_leads_updated_at
    BEFORE UPDATE ON leads
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_applications_updated_at
    BEFORE UPDATE ON applications
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tasks_updated_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Comments for documentation
COMMENT ON TABLE leads IS 'Stores lead information for counselors';
COMMENT ON TABLE applications IS 'Stores application records linked to leads';
COMMENT ON TABLE tasks IS 'Stores follow-up tasks for applications';
COMMENT ON CONSTRAINT tasks_type_check ON tasks IS 'Task type must be call, email, or review';
COMMENT ON CONSTRAINT tasks_due_at_after_created_check ON tasks IS 'Due date must be after creation date';

-- TODO:
-- - add check constraint for type in ('call','email','review')
-- - add constraint that due_at >= created_at
-- - add indexes for tasks due today by tenant_id, due_at, status
