SELECT * FROM layouts
GROUP BY outward + same_finger_rp + jumps
ORDER BY outward + same_finger_rp + jumps, score DESC;
