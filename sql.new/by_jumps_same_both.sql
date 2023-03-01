SELECT * FROM layouts
WHERE same_finger_rp < 70 and
jumps < 20 and
outward < 100
ORDER BY jumps + same_finger_im + same_finger_rp, outward, positional_effort, score DESC;
