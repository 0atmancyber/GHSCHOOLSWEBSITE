-- Trigger: enqueue SMS intent when a payment is inserted or updated to paid/approved
-- Run this in Supabase SQL editor (or via psql) to automatically create an sms_messages intent

create or replace function public.enqueue_sms_on_payment()
returns trigger
language plpgsql
as $$
begin
  -- Only enqueue on INSERT or when status transitions to a paid/approved state
  if (tg_op = 'INSERT') then
    if (new.status is not null and lower(new.status) in ('paid','approved')) then
      -- try to pick phone from payment row first, then from students table
      declare
        _phone text := null;
        _student_phone text := null;
      begin
        _phone := coalesce(new.phone, new.student_phone, new.phone_number, null);
        if _phone is null and new.student_id is not null then
          begin
            select coalesce(phone, phone_number, mobile, '') into _student_phone from public.students where student_id = new.student_id limit 1;
            if _student_phone = '' then _student_phone := null; end if;
          exception when others then
            _student_phone := null;
          end;
        end if;

        insert into public.sms_messages (student_id, phone, message, template, status, created_at)
        values (
          new.student_id,
          coalesce(_phone, _student_phone),
          concat('GH TECHNICAL — Hi ', coalesce(new.student_name, ''), ', we received your payment of GHS ', coalesce(new.amount::text, ''), ' for ', coalesce(new.payment_type, 'fees'), '. Thank you.'),
          'payment_received',
          'intent_created',
          now()
        );
      end;
    end if;
  elsif (tg_op = 'UPDATE') then
    if ( (old.status is distinct from new.status) and new.status is not null and lower(new.status) in ('paid','approved') ) then
      declare
        _phone text := null;
        _student_phone text := null;
      begin
        _phone := coalesce(new.phone, new.student_phone, new.phone_number, null);
        if _phone is null and new.student_id is not null then
          begin
            select coalesce(phone, phone_number, mobile, '') into _student_phone from public.students where student_id = new.student_id limit 1;
            if _student_phone = '' then _student_phone := null; end if;
          exception when others then
            _student_phone := null;
          end;
        end if;

        insert into public.sms_messages (student_id, phone, message, template, status, created_at)
        values (
          new.student_id,
          coalesce(_phone, _student_phone),
          concat('GH TECHNICAL — Hi ', coalesce(new.student_name, ''), ', we received your payment of GHS ', coalesce(new.amount::text, ''), ' for ', coalesce(new.payment_type, 'fees'), '. Thank you.'),
          'payment_received',
          'intent_created',
          now()
        );
      end;
    end if;
  end if;
  return new;
end;
$$;

-- Attach trigger to canonical payments table (adjust table name if different)
drop trigger if exists trg_enqueue_sms_on_payments on public.payments;
create trigger trg_enqueue_sms_on_payments
after insert or update on public.payments
for each row
execute function public.enqueue_sms_on_payment();
