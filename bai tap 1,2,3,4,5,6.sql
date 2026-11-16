DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;

-- 1. Bảng sinh viên
CREATE TABLE students (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL
);

-- 2. Bảng khóa học
CREATE TABLE courses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

-- 3. Bảng đăng ký học và điểm
CREATE TABLE enrollments (
    id SERIAL PRIMARY KEY,
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    grade NUMERIC(4, 2) NOT NULL CHECK (grade >= 0 AND grade <= 10),

    CONSTRAINT fk_enrollments_student
        FOREIGN KEY (student_id)
        REFERENCES students(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_enrollments_course
        FOREIGN KEY (course_id)
        REFERENCES courses(id)
        ON DELETE CASCADE
);

-- Thêm sinh viên mẫu
INSERT INTO students (full_name) VALUES
('Nguyễn Văn An'),
('Trần Thị Bình'),
('Lê Minh Cường'),
('Phạm Ngọc Dung');

-- Thêm khóa học mẫu
INSERT INTO courses (name) VALUES
('PostgreSQL Cơ bản'),
('Lập trình Java'),
('Lập trình Web');

-- Thêm dữ liệu đăng ký và điểm
INSERT INTO enrollments (student_id, course_id, grade) VALUES
(1, 1, 8.50),
(2, 1, 9.00),
(3, 1, 7.50),
(1, 2, 8.00),
(3, 2, 9.50),
(4, 3, 7.00);

--Truy vấn bài 1 
SELECT
    c.name AS course_name,
    COUNT(s.id) AS total_students,
    ROUND(AVG(e.grade), 2) AS average_grade
FROM courses c
LEFT JOIN enrollments e ON e.course_id = c.id
LEFT JOIN students s ON s.id = e.student_id
GROUP BY c.id, c.name
ORDER BY average_grade DESC NULLS LAST;

--Truy vấn này trong Query Tool:
WITH student_gpa AS (
    SELECT
        s.id,
        s.full_name,
        ROUND(AVG(e.grade), 2) AS gpa
    FROM students s
    JOIN enrollments e ON e.student_id = s.id
    GROUP BY s.id, s.full_name
),
school_average AS (
    SELECT AVG(gpa) AS average_gpa
    FROM student_gpa
)
SELECT
    sg.full_name,
    sg.gpa
FROM student_gpa sg
CROSS JOIN school_average sa
WHERE sg.gpa > sa.average_gpa
ORDER BY sg.gpa DESC;

--Bài 3 
-- Kiểm tra tên học sinh
SELECT s.full_name, c.name AS course_name, e.grade
FROM enrollments e
JOIN students s ON s.id = e.student_id
JOIN courses c ON c.id = e.course_id
WHERE s.full_name = 'Nguyễn Văn An';
-- Tạo lỗi 
BEGIN;

SAVEPOINT before_transfer;

-- Xóa đăng ký khóa học cũ
DELETE FROM enrollments
WHERE student_id = (
    SELECT id FROM students
    WHERE full_name = 'Nguyễn Văn An'
)
AND course_id = (
    SELECT id FROM courses
    WHERE name = 'PostgreSQL Cơ bản'
);

-- Savepoint sau khi xóa: dùng để minh họa
SAVEPOINT after_delete;

-- Cố tình vi phạm CHECK constraint
INSERT INTO enrollments (student_id, course_id, grade)
VALUES (
    (SELECT id FROM students WHERE full_name = 'Nguyễn Văn An'),
    (SELECT id FROM courses WHERE name = 'Lập trình Web'),
    11.00
);
-- Khôi phục:
ROLLBACK TO SAVEPOINT before_transfer;

COMMIT;

--Bài 4

ALTER TABLE students
ADD COLUMN extra_info JSONB;

--Update 2 học sinh
UPDATE students
SET extra_info = '{
    "skills": ["Giao tiếp", "Làm việc nhóm"],
    "toeic": 750
}'::JSONB
WHERE full_name = 'Nguyễn Văn An';

UPDATE students
SET extra_info = '{
    "skills": ["Thuyết trình", "Giải quyết vấn đề"],
    "toeic": 650
}'::JSONB
WHERE full_name = 'Trần Thị Bình';

--sinh viên có TOEIC từ 700

SELECT
    id,
    full_name,
    extra_info -> 'skills' AS skills,
    (extra_info ->> 'toeic')::INT AS toeic_score
FROM students
WHERE (extra_info ->> 'toeic')::INT >= 700;

--Bài 5
--Tạo bảng departments
CREATE TABLE departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

ALTER TABLE students
ADD COLUMN dept_id INT
REFERENCES departments(id);
--Thêm dư liệu
INSERT INTO departments (name) VALUES
('Công nghệ thông tin'),
('Kinh doanh');

UPDATE students
SET dept_id = (
    SELECT id
    FROM departments
    WHERE name = 'Công nghệ thông tin'
)
WHERE full_name IN ('Nguyễn Văn An', 'Lê Minh Cường');

UPDATE students
SET dept_id = (
    SELECT id
    FROM departments
    WHERE name = 'Kinh doanh'
)
WHERE full_name IN ('Trần Thị Bình', 'Phạm Ngọc Dung');

--Truy vấn 
WITH student_gpa AS (
    SELECT
        s.id,
        s.full_name,
        s.dept_id,
        ROUND(AVG(e.grade), 2) AS gpa
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
--bài 6
--Tạo cột email
ALTER TABLE students
ADD COLUMN email VARCHAR(255);

UPDATE students
SET email = CASE full_name
    WHEN 'Nguyễn Văn An' THEN 'nguyenvanan@example.com'
    WHEN 'Trần Thị Bình' THEN 'tranthibinh@example.com'
    WHEN 'Lê Minh Cường' THEN 'leminhcuong@example.com'
    WHEN 'Phạm Ngọc Dung' THEN 'phamngocdung@example.com'
END;

EXPLAIN ANALYZE
SELECT *
FROM students
WHERE email = 'nguyenvanan@example.com';

--Tạo UNIQUE INDEX

CREATE UNIQUE INDEX idx_students_email
ON students (email);

ANALYZE students;

EXPLAIN ANALYZE
SELECT *
FROM students
WHERE email = 'nguyenvanan@example.com';