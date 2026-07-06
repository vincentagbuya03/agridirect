-- Create crop_milestones table
CREATE TABLE IF NOT EXISTS public.crop_milestones (
    milestone_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES public.products(product_id) ON DELETE CASCADE,
    title VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for crop_milestones
ALTER TABLE public.crop_milestones ENABLE ROW LEVEL SECURITY;

-- Create policies for crop_milestones
CREATE POLICY "Allow public read access to crop milestones"
    ON public.crop_milestones FOR SELECT
    USING (true);

CREATE POLICY "Allow farmers to insert milestones for their own products"
    ON public.crop_milestones FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.products p
            WHERE p.product_id = crop_milestones.product_id
            AND p.farmer_id = auth.uid()
        )
    );

CREATE POLICY "Allow farmers to delete milestones for their own products"
    ON public.crop_milestones FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.products p
            WHERE p.product_id = crop_milestones.product_id
            AND p.farmer_id = auth.uid()
        )
    );
