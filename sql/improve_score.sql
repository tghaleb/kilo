SELECT * FROM layouts
WHERE
(jumps < 150) and
(outward < 250) and
(same_finger_rp < 500) and
((fingers0 + fingers9) < 2200) and
((fingers1 + fingers8) < 2600) and
((fingers3 + fingers6) < 4400)
ORDER BY score DESC, outward, same_finger_rp, jumps;

