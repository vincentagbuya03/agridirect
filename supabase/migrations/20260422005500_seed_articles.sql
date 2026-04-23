-- Migration: Seed Sample Articles
-- Created at: 2026-04-22 00:55:00

-- Insert sample articles if any admin exists
INSERT INTO admin_articles (admin_id, title, summary, body, cover_image_url, is_published, published_at)
SELECT 
    admin_id, 
    'Modern Irrigation Techniques', 
    'Learn how to optimize water usage in your farm using advanced drip systems.', 
    'Water management is crucial for sustainable farming. This guide covers the latest in drip irrigation and soil moisture monitoring...', 
    'https://images.unsplash.com/photo-1592982537447-6f2a6a0c7c18?auto=format&fit=crop&q=80&w=800', 
    true, 
    now()
FROM admins LIMIT 1;

INSERT INTO admin_articles (admin_id, title, summary, body, cover_image_url, is_published, published_at)
SELECT 
    admin_id, 
    'Organic Pest Management', 
    'Safe and effective ways to protect your crops without harsh chemicals.', 
    'Discover natural alternatives for pest control, including neem oil, companion planting, and biological controls...', 
    'https://images.unsplash.com/photo-1591857177580-dc82b9ac4e1e?auto=format&fit=crop&q=80&w=800', 
    true, 
    now()
FROM admins LIMIT 1;
