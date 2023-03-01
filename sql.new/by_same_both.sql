SELECT * FROM layouts
WHERE same_finger_rp < 70
ORDER BY same_finger_im + same_finger_rp;
