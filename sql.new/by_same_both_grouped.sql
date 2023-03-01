SELECT * FROM layouts
WHERE same_finger_rp < 70
GROUP BY same_finger_rp + same_finger_im
ORDER BY same_finger_rp + same_finger_im;
