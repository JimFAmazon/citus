--
-- TASK_TRACKER_PARTITION_TASK
--



\set JobId 401010
\set PartitionTaskId 801106

\set PartitionColumn l_orderkey
\set SelectAll 'SELECT *'

\set TablePart00 lineitem_partition_task_part_00
\set TablePart01 lineitem_partition_task_part_01
\set TablePart02 lineitem_partition_task_part_02

SELECT usesysid AS userid FROM pg_user WHERE usename = current_user \gset

\set File_Basedir  base/pgsql_job_cache
\set Table_File_00 :File_Basedir/job_:JobId/task_:PartitionTaskId/p_00000.:userid
\set Table_File_01 :File_Basedir/job_:JobId/task_:PartitionTaskId/p_00001.:userid
\set Table_File_02 :File_Basedir/job_:JobId/task_:PartitionTaskId/p_00002.:userid

-- We assign a partition task and wait for it to complete. Note that we hardcode
-- the partition function call string, including the job and task identifiers,
-- into the argument in the task assignment function. This hardcoding is
-- necessary as the current psql version does not perform variable interpolation
-- for names inside single quotes.

SELECT task_tracker_assign_task(:JobId, :PartitionTaskId,
       				'SELECT worker_range_partition_table('
				'401010, 801106, ''SELECT * FROM lineitem'', '
				'''l_orderkey'', 20, ARRAY[1000, 3000]::_int8)');

SELECT pg_sleep(4.0);

SELECT task_tracker_task_status(:JobId, :PartitionTaskId);

COPY :TablePart00 FROM :'Table_File_00';
COPY :TablePart01 FROM :'Table_File_01';
COPY :TablePart02 FROM :'Table_File_02';

SELECT COUNT(*) FROM :TablePart00;
SELECT COUNT(*) FROM :TablePart02;

-- We first compute the difference of partition tables against the base table.
-- Then, we compute the difference of the base table against partitioned tables.

SELECT COUNT(*) AS diff_lhs_00 FROM (
       :SelectAll FROM :TablePart00 EXCEPT ALL
       :SelectAll FROM lineitem WHERE :PartitionColumn < 1000 ) diff;
SELECT COUNT(*) AS diff_lhs_01 FROM (
       :SelectAll FROM :TablePart01 EXCEPT ALL
       :SelectAll FROM lineitem WHERE :PartitionColumn >= 1000 AND
       		   		      :PartitionColumn < 3000 ) diff;
SELECT COUNT(*) AS diff_lhs_02 FROM (
       :SelectAll FROM :TablePart02 EXCEPT ALL
       :SelectAll FROM lineitem WHERE :PartitionColumn >= 3000 ) diff;

SELECT COUNT(*) AS diff_rhs_00 FROM (
       :SelectAll FROM lineitem WHERE :PartitionColumn < 1000 EXCEPT ALL
       :SelectAll FROM :TablePart00 ) diff;
SELECT COUNT(*) AS diff_rhs_01 FROM (
       :SelectAll FROM lineitem WHERE :PartitionColumn >= 1000 AND
       		   		      :PartitionColumn < 3000 EXCEPT ALL
       :SelectAll FROM :TablePart01 ) diff;
SELECT COUNT(*) AS diff_rhs_02 FROM (
       :SelectAll FROM lineitem WHERE :PartitionColumn >= 3000 EXCEPT ALL
       :SelectAll FROM :TablePart02 ) diff;
