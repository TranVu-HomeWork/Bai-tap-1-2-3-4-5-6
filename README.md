# Báo cáo thực hành PostgreSQL – Session 1

## Thông tin thực hành

- Công cụ: PostgreSQL 18 và pgAdmin 4.
- Chủ đề: PostgreSQL Fundamentals & Core SQL.
- Dữ liệu dùng để thực hành: sinh viên, khóa học và đăng ký học.
- File lệnh: `bai tap 1,2,3,4,5,6.sql`.

## Chuẩn bị cơ sở dữ liệu

Hệ thống được khởi tạo với ba bảng có quan hệ:

- `students`: lưu mã và họ tên sinh viên.
- `courses`: lưu mã và tên khóa học.
- `enrollments`: liên kết sinh viên với khóa học, lưu điểm `grade` từ 0 đến 10.

Hai khóa ngoại trong `enrollments` được cấu hình `ON DELETE CASCADE`, giúp xóa các đăng ký liên quan khi sinh viên hoặc khóa học bị xóa. Dữ liệu mẫu gồm bốn sinh viên, ba khóa học và sáu lượt đăng ký.

## Bài 1 – Truy vấn đa bảng và thống kê

Thực hiện `LEFT JOIN` giữa `courses`, `enrollments` và `students`; sau đó nhóm theo khóa học để đếm số sinh viên và tính điểm trung bình.

```sql
SELECT
    c.name AS course_name,
    COUNT(s.id) AS total_students,
    ROUND(AVG(e.grade), 2) AS average_grade
FROM courses c
LEFT JOIN enrollments e ON e.course_id = c.id
LEFT JOIN students s ON s.id = e.student_id
GROUP BY c.id, c.name
ORDER BY average_grade DESC NULLS LAST;
```

Kết quả với dữ liệu mẫu được sắp xếp giảm dần theo điểm trung bình: Lập trình Java có 2 sinh viên và điểm trung bình 8.75; PostgreSQL Cơ bản có 3 sinh viên và điểm trung bình 8.33; Lập trình Web có 1 sinh viên và điểm trung bình 7.00.

## Bài 2 – Subquery và CTE

Sử dụng CTE đầu tiên để tính GPA từng sinh viên; CTE thứ hai tính GPA trung bình toàn trường. Truy vấn cuối lọc sinh viên có GPA cao hơn mức trung bình.

```sql
WITH student_gpa AS (
    SELECT s.id, s.full_name, ROUND(AVG(e.grade), 2) AS gpa
    FROM students s
    JOIN enrollments e ON e.student_id = s.id
    GROUP BY s.id, s.full_name
),
school_average AS (
    SELECT AVG(gpa) AS average_gpa FROM student_gpa
)
SELECT sg.full_name, sg.gpa
FROM student_gpa sg
CROSS JOIN school_average sa
WHERE sg.gpa > sa.average_gpa
ORDER BY sg.gpa DESC;
```

Kết quả mong đợi: Trần Thị Bình (9.00), Lê Minh Cường (8.50) và Nguyễn Văn An (8.25) có GPA cao hơn GPA trung bình của toàn trường.

## Bài 3 – Transactions và Savepoints

Mô phỏng chuyển khóa học cho Nguyễn Văn An. Giao dịch xóa đăng ký `PostgreSQL Cơ bản`, sau đó cố tình thêm một đăng ký mới có điểm `11.00` để vi phạm `CHECK (grade <= 10)`.

```sql
BEGIN;
SAVEPOINT before_transfer;

DELETE FROM enrollments
WHERE student_id = (SELECT id FROM students WHERE full_name = 'Nguyễn Văn An')
  AND course_id = (SELECT id FROM courses WHERE name = 'PostgreSQL Cơ bản');

SAVEPOINT after_delete;

INSERT INTO enrollments (student_id, course_id, grade)
VALUES (
    (SELECT id FROM students WHERE full_name = 'Nguyễn Văn An'),
    (SELECT id FROM courses WHERE name = 'Lập trình Web'),
    11.00
);

ROLLBACK TO SAVEPOINT before_transfer;
COMMIT;
```

Kết quả: PostgreSQL báo lỗi constraint ở thao tác thêm mới. `ROLLBACK TO SAVEPOINT before_transfer` phục hồi đăng ký cũ, vì vậy dữ liệu không bị hỏng.

## Bài 4 – Xử lý dữ liệu JSONB

Thêm cột `extra_info` kiểu `JSONB` để lưu các thông tin thay đổi linh hoạt như kỹ năng và điểm TOEIC.

```sql
ALTER TABLE students ADD COLUMN extra_info JSONB;

UPDATE students
SET extra_info = '{"skills": ["Giao tiếp", "Làm việc nhóm"], "toeic": 750}'::JSONB
WHERE full_name = 'Nguyễn Văn An';

SELECT
    id,
    full_name,
    extra_info -> 'skills' AS skills,
    (extra_info ->> 'toeic')::INT AS toeic_score
FROM students
WHERE (extra_info ->> 'toeic')::INT >= 700;
```

Kết quả: truy vấn trích xuất được dữ liệu nằm trong JSONB; Nguyễn Văn An có TOEIC 750 và thỏa điều kiện lọc.

## Bài 5 – Window Functions

Tạo bảng `departments`, thêm `dept_id` cho bảng `students` rồi dùng `RANK()` để xếp hạng GPA theo từng phòng ban.

```sql
WITH student_gpa AS (
    SELECT s.id, s.full_name, s.dept_id, ROUND(AVG(e.grade), 2) AS gpa
    FROM students s
    JOIN enrollments e ON e.student_id = s.id
    GROUP BY s.id, s.full_name, s.dept_id
)
SELECT
    sg.full_name AS student_name,
    d.name AS department_name,
    sg.gpa,
    RANK() OVER (
        PARTITION BY sg.dept_id
        ORDER BY sg.gpa DESC
    ) AS rank_in_department
FROM student_gpa sg
JOIN departments d ON d.id = sg.dept_id
ORDER BY d.name, rank_in_department;
```

Kết quả: mỗi phòng ban có bảng xếp hạng riêng. `PARTITION BY dept_id` tách dữ liệu theo phòng ban, còn `RANK()` xếp hạng GPA từ cao xuống thấp.

## Bài 6 – Tối ưu hóa với Indexing

Thêm email cho sinh viên, dùng `EXPLAIN ANALYZE` kiểm tra kế hoạch truy vấn trước và sau khi tạo unique index.

```sql
EXPLAIN ANALYZE
SELECT * FROM students
WHERE email = 'nguyenvanan@example.com';

CREATE UNIQUE INDEX idx_students_email
ON students (email);

ANALYZE students;

EXPLAIN ANALYZE
SELECT * FROM students
WHERE email = 'nguyenvanan@example.com';
```

Khi bảng có nhiều dữ liệu, index trên `email` giúp PostgreSQL tìm bản ghi nhanh hơn và thường chuyển kế hoạch từ `Seq Scan` sang `Index Scan` hoặc `Index Only Scan`. Với bộ dữ liệu mẫu rất nhỏ, hệ quản trị có thể vẫn chọn `Seq Scan` do chi phí thấp hơn.

## Kết luận

Qua sáu bài tập, đã thực hành truy vấn nhiều bảng, tổng hợp dữ liệu, CTE, giao dịch an toàn, JSONB, window function và tối ưu truy vấn bằng index. Các kỹ thuật này hỗ trợ thiết kế hệ thống PostgreSQL đúng đắn, an toàn và hiệu quả hơn.

## Ảnh minh chứng cần bổ sung

Chụp và chèn ảnh phần **Data Output** trong pgAdmin cho các nội dung sau trước khi nộp bài:

1. Kết quả bài 1: JOIN và thống kê khóa học.
2. Kết quả bài 2: danh sách sinh viên có GPA cao hơn trung bình.
3. Kết quả bài 4: sinh viên có TOEIC từ 700.
4. Kết quả bài 5: xếp hạng GPA theo phòng ban.
5. Output `EXPLAIN ANALYZE` trước và sau khi tạo index ở bài 6.
