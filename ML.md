### Short Explanation:

1. **Detection**: **Google BlazeFace** locates the face and its key landmarks (eyes, nose, mouth, cheeks) on both photos.
2. **Geometric Comparison (70%)**: The app measures the facial proportions (like eye-to-nose and eye-to-mouth distance) and calculates their **Cosine Similarity**.
3. **Pixel Comparison (30%)**: Both faces are cropped into $64\times64$ grayscale images and compared for structural pixel match.
4. **Result**: If the combined score is **$\ge 65\%$**, it is verified as the same person!


"We use Euclidean Inter-Pupillary Normalization, Cosine Similarity on facial geometry vectors, and Grayscale Pixel Intensity Correlation, combined via Weighted Score Fusion."