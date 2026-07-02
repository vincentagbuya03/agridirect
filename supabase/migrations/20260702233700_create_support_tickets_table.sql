-- Migration to create the support_tickets table
CREATE TABLE IF NOT EXISTS public.support_tickets (
    ticket_id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_email text NOT NULL,
    user_name text NOT NULL,
    subject text NOT NULL,
    message_text text NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Enable RLS (Row Level Security)
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

-- Allow anyone to insert tickets (since users submitting them might not be logged in or are standard consumers)
CREATE POLICY "Allow public insert to support_tickets" 
ON public.support_tickets 
FOR INSERT 
WITH CHECK (true);

-- Allow authenticated users who are admins to view all tickets
CREATE POLICY "Allow admin read to support_tickets" 
ON public.support_tickets 
FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM public.admins a 
        WHERE a.user_id = auth.uid()
    )
);

-- Allow admins to update support tickets status
CREATE POLICY "Allow admin update to support_tickets" 
ON public.support_tickets 
FOR UPDATE 
USING (
    EXISTS (
        SELECT 1 FROM public.admins a 
        WHERE a.user_id = auth.uid()
    )
);
