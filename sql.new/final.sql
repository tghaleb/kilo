SELECT * FROM layouts
WHERE
(jumps < 100) and
(outward < 100) and
(same_finger_rp < 100) and
((fingers0 + fingers9) < 2000) and
((fingers1 + fingers8) < 2600) and
((fingers3 + fingers6) < 4200)
ORDER BY
outward + jumps + same_finger_rp DESC,
outward,
same_finger_rp,
effort DESC,
alternation DESC,
score DESC,
text_direction DESC,
(fingers0 + fingers9),
;

