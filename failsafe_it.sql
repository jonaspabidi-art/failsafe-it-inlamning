/* ============================================================================
   FAILSAFE IT - KUND-, KONSULT- OCH UPPDRAGSREGISTER
   INLÄMNINGSUPPGIFT 1: Datamodellering, DDL, DML och frågor
   Namnstandard: PK heter alltid Id. FK heter <Tabellnamn>Id.
   ============================================================================ */


-- INITIALISERING (Rensar och förbereder databasen)

USE master;
GO

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'FailSafe_Inlamning1')
BEGIN
    ALTER DATABASE FailSafe_Inlamning1 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE FailSafe_Inlamning1;
END
GO

CREATE DATABASE FailSafe_Inlamning1;
GO

USE FailSafe_Inlamning1;
GO

-- BLOCK 1: DDL - SKAPA TABELLER (3NF)

CREATE TABLE Customers (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    OrgNumber VARCHAR(11) NOT NULL,              -- format 556677-8899
    CompanyName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(255) NOT NULL,
    Phone VARCHAR(20) NOT NULL,
    -- UNIQUE NONCLUSTERED ger ett index för snabba sökningar på org.nummer
    CONSTRAINT UQ_Customers_OrgNumber UNIQUE NONCLUSTERED (OrgNumber)
);

CREATE TABLE Specialties (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    SpecialtyName NVARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Consultants (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    PersonalNumber CHAR(13) NOT NULL UNIQUE,     -- format ÅÅÅÅMMDD-XXXX
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    HourlyRate DECIMAL(10,2) NOT NULL,
    SpecialtiesId INT NOT NULL,
    CONSTRAINT CK_Consultants_HourlyRate CHECK (HourlyRate > 0),
    CONSTRAINT FK_Consultants_Specialties FOREIGN KEY (SpecialtiesId) REFERENCES Specialties(Id)
);

-- Kopplingstabell som löser upp M:M mellan Customers och Consultants.
-- Egen Id (inte sammansatt PK) eftersom samma kund kan hyra samma konsult
-- för flera olika uppdrag, och varje uppdrag har egna attribut.
CREATE TABLE Assignments (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    CustomersId INT NOT NULL,
    ConsultantsId INT NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    RoleDescription NVARCHAR(200) NOT NULL,
    CONSTRAINT CK_Assignments_Dates CHECK (EndDate >= StartDate),
    CONSTRAINT FK_Assignments_Customers FOREIGN KEY (CustomersId) REFERENCES Customers(Id),
    CONSTRAINT FK_Assignments_Consultants FOREIGN KEY (ConsultantsId) REFERENCES Consultants(Id)
);
GO

-- Index på FK-kolumnerna: snabbare JOINs och FK-validering vid DELETE
CREATE NONCLUSTERED INDEX IX_Assignments_CustomersId ON Assignments(CustomersId);
CREATE NONCLUSTERED INDEX IX_Assignments_ConsultantsId ON Assignments(ConsultantsId);
GO



-- BLOCK 2: DML - SEED-DATA

INSERT INTO Customers (OrgNumber, CompanyName, Email, Phone) VALUES
('556123-4567', 'Nordbank AB', 'it@nordbank.se', '031-1234567'),
('559876-5432', 'Västkust Logistik AB', 'kontakt@vklogistik.se', '031-7654321'),
('556555-1212', 'Hälsodata Sverige AB', 'info@halsodata.se', '08-5551212'),
('559000-1111', 'Testbolaget AB', 'hej@testbolaget.se', '070-1112233'); -- Kund utan uppdrag (För DELETE)

INSERT INTO Specialties (SpecialtyName) VALUES
('Cybersecurity'),
('DevOps'),
('C# Developer');

INSERT INTO Consultants (PersonalNumber, FirstName, LastName, HourlyRate, SpecialtiesId) VALUES
('19880412-1234', 'Sara', 'Lindqvist', 1450.00, 1),
('19920905-5678', 'Ahmed', 'Karimi', 1250.00, 2),
('19950117-9012', 'Johan', 'Berg', 950.00, 3),
('19900630-3456', 'Elin', 'Holm', 1100.00, 1);

INSERT INTO Assignments (CustomersId, ConsultantsId, StartDate, EndDate, RoleDescription) VALUES
(1, 1, '2026-09-01', '2026-12-31', 'Säkerhetsgranskning av API-miljö'),
(1, 3, '2026-10-01', '2027-03-31', 'Vidareutveckling av internt C#-system'),
(2, 2, '2026-08-15', '2026-11-30', 'Uppsättning av CI/CD-pipeline'),
(3, 4, '2026-11-01', '2027-01-31', 'Penetrationstest av patientportal'),
(3, 2, '2026-06-01', '2026-08-31', 'Migrering av infrastruktur till molnet');
GO

-- BLOCK 3: FRÅGOR

-- Fråga A
-- Lista namn och timpris på alla konsulter med timpris högre än 1200 kr,
-- sorterat efter pris (högst först).
SELECT c.FirstName + ' ' + c.LastName AS ConsultantName, c.HourlyRate
FROM Consultants c
WHERE c.HourlyRate > 1200
ORDER BY c.HourlyRate DESC;
GO

-- Fråga B
-- Sammanställning över alla uppdrag: kundens företagsnamn, konsultens namn,
-- samt start- och slutdatum.
SELECT cu.CompanyName, co.FirstName + ' ' + co.LastName AS ConsultantName,
       a.StartDate, a.EndDate, a.RoleDescription
FROM Assignments a
INNER JOIN Customers cu ON a.CustomersId = cu.Id
INNER JOIN Consultants co ON a.ConsultantsId = co.Id
ORDER BY a.StartDate;
GO

-- Fråga C
-- Alla kunder och hur många uppdrag respektive kund har totalt.
-- LEFT JOIN så att kunder utan uppdrag också visas (med 0).
SELECT cu.CompanyName, COUNT(a.Id) AS NumberOfAssignments
FROM Customers cu
LEFT JOIN Assignments a ON cu.Id = a.CustomersId
GROUP BY cu.Id, cu.CompanyName
ORDER BY NumberOfAssignments DESC;
GO

-- Fråga D
-- Uppdatera timpriset för en specifik konsult.
UPDATE Consultants
SET HourlyRate = 1050.00
WHERE PersonalNumber = '19950117-9012';

-- Verifiera uppdateringen
SELECT FirstName, LastName, HourlyRate FROM Consultants WHERE PersonalNumber = '19950117-9012';
GO

-- Fråga E
-- Ta bort en kund, förutsatt att kunden inte har några uppdrag kopplade till sig.
DELETE FROM Customers
WHERE OrgNumber = '559000-1111'
  AND NOT EXISTS (SELECT 1 FROM Assignments a WHERE a.CustomersId = Customers.Id);

-- Verifiera borttagningen
SELECT * FROM Customers;
GO

-- BLOCK 4: AUTOMATISERAD VERIFIERINGSLOGG (Pipeline-kontroll)

SELECT 'Customers' AS [Table Name], COUNT(*) AS [Number of records] FROM Customers
UNION ALL
SELECT 'Specialties', COUNT(*) FROM Specialties
UNION ALL
SELECT 'Consultants', COUNT(*) FROM Consultants
UNION ALL
SELECT 'Assignments', COUNT(*) FROM Assignments;
GO

PRINT 'FailSafeIT-databasen är skapad, fylld med testdata och alla frågor är körda!';
