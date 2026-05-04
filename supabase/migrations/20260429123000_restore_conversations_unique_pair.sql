-- Restore the unique customer/farmer conversation pair required by preorder
-- and message flows. If duplicates already exist, keep the oldest row, move
-- messages to it, then remove the duplicate conversation rows.

WITH ranked_conversations AS (
  SELECT
    conversation_id,
    first_value(conversation_id) OVER (
      PARTITION BY customer_id, farmer_id
      ORDER BY created_at ASC NULLS LAST, conversation_id ASC
    ) AS keeper_conversation_id,
    row_number() OVER (
      PARTITION BY customer_id, farmer_id
      ORDER BY created_at ASC NULLS LAST, conversation_id ASC
    ) AS row_number
  FROM public.conversations
),
duplicates AS (
  SELECT conversation_id, keeper_conversation_id
  FROM ranked_conversations
  WHERE row_number > 1
)
UPDATE public.messages m
SET conversation_id = d.keeper_conversation_id
FROM duplicates d
WHERE m.conversation_id = d.conversation_id;

WITH ranked_conversations AS (
  SELECT
    conversation_id,
    row_number() OVER (
      PARTITION BY customer_id, farmer_id
      ORDER BY created_at ASC NULLS LAST, conversation_id ASC
    ) AS row_number
  FROM public.conversations
)
DELETE FROM public.conversations c
USING ranked_conversations r
WHERE c.conversation_id = r.conversation_id
  AND r.row_number > 1;

ALTER TABLE public.conversations
  ADD CONSTRAINT conversations_customer_farmer_unique
  UNIQUE (customer_id, farmer_id);
