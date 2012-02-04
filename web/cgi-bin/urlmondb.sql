-- MySQL dump 10.13  Distrib 5.1.60, for redhat-linux-gnu (x86_64)
--
-- Host: localhost    Database: urlmon
-- ------------------------------------------------------
-- Server version	5.1.60

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `groups`
--

DROP TABLE IF EXISTS `groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `groups` (
  `name` varchar(50) NOT NULL,
  `url_id` int(11) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `groups`
--

LOCK TABLES `groups` WRITE;
/*!40000 ALTER TABLE `groups` DISABLE KEYS */;
/*!40000 ALTER TABLE `groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `logs`
--

DROP TABLE IF EXISTS `logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `logs` (
  `dt` datetime NOT NULL,
  `url_id` int(11) NOT NULL,
  `status` int(11) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `logs`
--

LOCK TABLES `logs` WRITE;
/*!40000 ALTER TABLE `logs` DISABLE KEYS */;
INSERT INTO `logs` VALUES ('2012-01-27 21:19:53',1,0),('2012-01-27 21:19:53',2,0),('2012-01-27 21:19:53',3,0),('2012-01-27 21:19:53',4,0),('2012-01-27 21:19:53',5,0),('2012-01-27 21:19:53',6,0),('2012-01-27 21:19:53',7,0),('2012-01-27 21:19:53',8,0),('2012-01-27 21:19:53',9,0),('2012-01-27 21:19:53',10,0),('2012-01-27 21:19:53',11,0),('2012-01-27 21:19:53',12,0),('2012-01-27 21:20:07',1,0),('2012-01-27 21:20:07',2,0),('2012-01-27 21:20:07',3,0),('2012-01-27 21:20:07',4,0),('2012-01-27 21:20:07',5,0),('2012-01-27 21:20:07',6,0),('2012-01-27 21:20:07',7,0),('2012-01-27 21:20:07',8,0),('2012-01-27 21:20:07',9,0),('2012-01-27 21:20:07',10,0),('2012-01-27 21:20:07',11,0),('2012-01-27 21:20:07',12,0),('2012-01-27 21:21:36',1,0),('2012-01-27 21:21:36',2,0),('2012-01-27 21:21:36',3,0),('2012-01-27 21:21:36',4,0),('2012-01-27 21:21:36',5,0),('2012-01-27 21:21:36',6,0),('2012-01-27 21:21:36',7,0),('2012-01-27 21:21:36',8,0),('2012-01-27 21:21:36',9,0),('2012-01-27 21:21:36',10,0),('2012-01-27 21:21:36',11,0),('2012-01-27 21:21:36',12,0),('2012-01-28 16:38:22',13,0),('2012-01-28 16:45:47',13,1),('2012-01-28 22:19:20',13,0),('2012-01-28 22:28:15',13,1),('2012-01-28 22:30:53',13,0);
/*!40000 ALTER TABLE `logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notifications` (
  `url_id` int(11) NOT NULL,
  `mail` varchar(100) NOT NULL,
  `type` int(11) NOT NULL,
  UNIQUE KEY `uq_entry` (`url_id`,`mail`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
INSERT INTO `notifications` VALUES (13,'gabriela.tzanova@gmail.com',2);
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `urls`
--

DROP TABLE IF EXISTS `urls`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `urls` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `url` varchar(200) NOT NULL,
  `int_sec` bigint(20) NOT NULL,
  `l_checked` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=14 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `urls`
--

LOCK TABLES `urls` WRITE;
/*!40000 ALTER TABLE `urls` DISABLE KEYS */;
INSERT INTO `urls` VALUES (1,'abc',123,'2012-01-28 22:58:43'),(2,'qwe',456,'2012-01-28 22:58:43'),(3,'\'abx, 3);DELETE FROM urls where id=1;\'',3600,'2012-01-28 22:04:56'),(4,'\'abc\'',3600,'2012-01-28 22:04:56'),(5,'\'abc\'',3600,'2012-01-28 22:04:56'),(6,'\'0908\'',3600,'2012-01-28 22:04:56'),(7,'\'abc\'',3600,'2012-01-28 22:04:56'),(8,'\'abc\'',3600,'2012-01-28 22:04:56'),(9,'\'0987\'',3600,'2012-01-28 22:04:56'),(10,'\'0987\'',3600,'2012-01-28 22:04:56'),(11,'\'0987\'',3600,'2012-01-28 22:04:56'),(12,'\'abc\'',3600,'2012-01-28 22:04:56'),(13,'blah',10,'2012-01-28 22:58:43');
/*!40000 ALTER TABLE `urls` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2012-01-29 15:49:41
