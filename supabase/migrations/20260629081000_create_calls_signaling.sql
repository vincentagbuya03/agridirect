-- Create call_status enum
CREATE TYPE public.call_status AS ENUM ('ringing', 'connected', 'declined', 'ended', 'missed');

-- Create calls table for VoIP signaling
CREATE TABLE public.calls (
    call_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES public.conversations(conversation_id) ON DELETE CASCADE,
    caller_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    channel_name TEXT NOT NULL,
    is_video BOOLEAN NOT NULL DEFAULT false,
    status public.call_status NOT NULL DEFAULT 'ringing',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;

-- Select policy
CREATE POLICY "Users can view their own calls" 
ON public.calls FOR SELECT 
TO authenticated
USING (auth.uid() = caller_id OR auth.uid() = receiver_id);

-- Insert policy
CREATE POLICY "Users can create calls" 
ON public.calls FOR INSERT 
TO authenticated
WITH CHECK (auth.uid() = caller_id);

-- Update policy
CREATE POLICY "Users can update their own calls" 
ON public.calls FOR UPDATE 
TO authenticated
USING (auth.uid() = caller_id OR auth.uid() = receiver_id);

-- Enable Realtime for calls table
ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;
