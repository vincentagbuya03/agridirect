-- Create conversations table
CREATE TABLE public.conversations (
    conversation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(customer_id) ON DELETE CASCADE,
    farmer_id UUID NOT NULL REFERENCES public.farmers(farmer_id) ON DELETE CASCADE,
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(customer_id, farmer_id)
);

-- Create messages table
CREATE TABLE public.messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(conversation_id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT false,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable Realtime for messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- RLS Policies for conversations
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own conversations" 
ON public.conversations FOR SELECT 
TO authenticated
USING (
    customer_id IN (SELECT customer_id FROM public.customers WHERE user_id = auth.uid())
    OR 
    farmer_id IN (SELECT farmer_id FROM public.farmers WHERE user_id = auth.uid())
);

CREATE POLICY "Customers can create conversations" 
ON public.conversations FOR INSERT 
TO authenticated
WITH CHECK (
    customer_id IN (SELECT customer_id FROM public.customers WHERE user_id = auth.uid())
);

CREATE POLICY "Users can update their own conversations" 
ON public.conversations FOR UPDATE 
TO authenticated
USING (
    customer_id IN (SELECT customer_id FROM public.customers WHERE user_id = auth.uid())
    OR 
    farmer_id IN (SELECT farmer_id FROM public.farmers WHERE user_id = auth.uid())
);

-- RLS Policies for messages
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view messages in their conversations" 
ON public.messages FOR SELECT 
TO authenticated
USING (
    conversation_id IN (
        SELECT conversation_id FROM public.conversations 
        WHERE customer_id IN (SELECT customer_id FROM public.customers WHERE user_id = auth.uid())
        OR farmer_id IN (SELECT farmer_id FROM public.farmers WHERE user_id = auth.uid())
    )
);

CREATE POLICY "Users can insert messages in their conversations" 
ON public.messages FOR INSERT 
TO authenticated
WITH CHECK (
    conversation_id IN (
        SELECT conversation_id FROM public.conversations 
        WHERE customer_id IN (SELECT customer_id FROM public.customers WHERE user_id = auth.uid())
        OR farmer_id IN (SELECT farmer_id FROM public.farmers WHERE user_id = auth.uid())
    )
    AND sender_id = auth.uid()
);

CREATE POLICY "Users can update messages in their conversations" 
ON public.messages FOR UPDATE 
TO authenticated
USING (
    conversation_id IN (
        SELECT conversation_id FROM public.conversations 
        WHERE customer_id IN (SELECT customer_id FROM public.customers WHERE user_id = auth.uid())
        OR farmer_id IN (SELECT farmer_id FROM public.farmers WHERE user_id = auth.uid())
    )
);
