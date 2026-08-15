-- Business question 1: Which customers have a high-severity incident ratio among completed services?
-- Technique: joins, conditional aggregation, and a ratio filter.

SET @as_of = TIMESTAMP('2025-11-15 12:00:00');

WITH incident_metrics AS (
    SELECT
        c.customer_id,
        c.name AS customer_name,
        COUNT(DISTINCT o.order_id) AS completed_service_requests,
        COUNT(DISTINCT i.incident_id) AS total_incidents,
        COUNT(DISTINCT CASE WHEN i.severity >= 4 THEN i.incident_id END)
            AS high_severity_incidents
    FROM Customer AS c
    LEFT JOIN `order` AS o
        ON o.customer_id = c.customer_id
       AND o.status = 'completed'
       AND o.request_time <= @as_of
    LEFT JOIN Incident AS i
        ON i.order_id = o.order_id
    GROUP BY c.customer_id, c.name
)
SELECT
    customer_id,
    customer_name,
    completed_service_requests,
    total_incidents,
    high_severity_incidents,
    ROUND(high_severity_incidents / NULLIF(completed_service_requests, 0), 2)
        AS high_severity_ratio
FROM incident_metrics
WHERE high_severity_incidents / NULLIF(completed_service_requests, 0) >= 0.30
ORDER BY customer_id;
