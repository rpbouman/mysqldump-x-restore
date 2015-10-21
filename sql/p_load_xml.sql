delimiter //

drop procedure p_load_xml
//

create procedure p_load_xml(
  /*
      p_spec: an xml document that describes the input data document

      <x table="" schema="" xpath="">
        <x column="" xpath="" expression=""/>
      </x>
  */
  p_spec  text
  /*
      p_xml: the input xml document
  */
, p_xml   text
)
begin
  declare v_schema          varchar(64)       default extractvalue(p_spec, '/*[1]/@schema');
  declare v_table           varchar(64)       default extractvalue(p_spec, '/*[1]/@table');
  declare v_xpath_row       text              default extractvalue(p_spec, '/*[1]/@xpath');
  declare v_show_statement  text              default extractvalue(p_spec, '/*[1]/@show');
  declare v_exec_statement  text              default extractvalue(p_spec, '/*[1]/@exec');

  declare v_num_rows        bigint unsigned   default cast(extractvalue(p_xml, concat('count(', v_xpath_row, ')')) as unsigned);
  declare v_row_index       bigint unsigned   default 0;

  declare v_num_fields      smallint unsigned default cast(extractvalue(p_spec, 'count(/*[1]/*)') as unsigned);
  declare v_field_index     smallint unsigned default 0;
  declare v_num_cols        smallint unsigned default 0;
  declare v_name            varchar(64);
  declare v_exclude         bool;
  declare v_xpath_column    text;
  declare v_exp_column      text;

  declare v_sql_insert      text              default 'INSERT INTO ';
  declare v_sql_o_select    text              default 'SELECT ';
  declare v_sql_i_select    text              default '';

  declare v_separator       char(1);

  -- create the table identifier (possibly prefixed by a schema)
  if length(v_schema) then
    set v_sql_insert = concat(v_sql_insert, '`', v_schema, '`.');
  end if;
  set v_sql_insert = concat(v_sql_insert, '`', v_table, '` (');

  -- loop over all elements in the xml data document identified by the path specified by the @xpath attribute in the document element.
  _ROWS: while v_row_index < v_num_rows do
    set v_row_index = v_row_index + 1
    ,   v_field_index = 0
    ;

    -- loop over all elements inside the document element of the spec document
    _FIELDS: while v_field_index < v_num_fields do

      set v_field_index = v_field_index + 1
      ,   v_name = concat('`', extractvalue(p_spec, concat('/*[1]/*[', v_field_index, ']/@column')), '`')
      ,   v_xpath_column = extractvalue(p_spec, concat('/*[1]/*[', v_field_index, ']/@xpath'))
      ,   v_exp_column = extractvalue(p_spec, concat('/*[1]/*[', v_field_index, ']/@expression'))
      ,   v_exclude = case extractvalue(p_spec, concat('/*[1]/*[', v_field_index, ']/@exclude'))
                        when 'true' then true
                        else false
                      end
      ,   v_sql_i_select =  concat(
                              v_sql_i_select
                            , case v_field_index
                                when 1 then concat(
                                    case v_row_index
                                      when 1 then ''
                                      else '\nUNION ALL'
                                    end
                                  , '\nSELECT'
                                  )
                                else '\n,'
                              end
                            , ' '''
                            , replace(extractvalue(p_xml, concat(v_xpath_row, '[', v_row_index, ']/', v_xpath_column)), '''', '''''')
                            , ''''
                            , case v_row_index
                                when 1 then concat(' AS ', v_name)
                                else ''
                              end
                            )
      ;

      if v_row_index = 1 then

        if v_exclude = 0 then
          set v_separator = case v_num_cols when 0 then ' ' else ',' end
          ,   v_sql_insert = concat(v_sql_insert, '\n', v_separator, ' ')
          ,   v_sql_o_select = concat(v_sql_o_select, '\n', v_separator, ' ')
          ,   v_num_cols = v_num_cols + 1
          ,   v_sql_insert = concat(v_sql_insert, v_name)
          ,   v_sql_o_select =  concat(
                                  v_sql_o_select
                                , case  length(v_exp_column)
                                    when 0 then concat(v_name)
                                    else v_exp_column
                                  end
                                )
          ;
        end if;

      end if;

    end while _FIELDS;
  end while _ROWS;

  set v_sql_o_select = concat(v_sql_o_select, '\nFROM (', v_sql_i_select, '\n) AS derived')
  ,   v_sql_insert = concat(v_sql_insert, '\n)\n', v_sql_o_select)
  ;

  if v_show_statement = 'true' then
    SELECT v_sql_insert;
  end if;

  if v_exec_statement != 'false' then
    set @stmt = v_sql_insert;
    prepare stmt from @stmt;
    execute stmt;
    deallocate prepare stmt;
  end if;
end;
//

delimiter ;

set @xml = '
<?xml version="1.0" encoding="UTF-8"?>
 <wovoml xmlns="http://www.wovodat.org"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 version="1.1.0" xsi:schemaLocation="http://www.wovodat.org phread2.xsd">
 <Data>
 <Seismic>
 <SingleStationEventDataset>
  <SingleStationEvent code="VTAG_20160405000000" owner1="169" pubDate="2018-04-05 00:00:00" station="101">
   <startTime>2016-04-05 00:00:00</startTime>
   <startTimeCsec>0</startTimeCsec>
   <startTimeUnc>0000-00-00 00:00:00</startTimeUnc>
   <startTimeCsecUnc>0</startTimeCsecUnc>
   <picksDetermination>H</picksDetermination>
   <SPInterval>12.5</SPInterval>
   <duration>50</duration>
   <durationUnc>0</durationUnc>
   <distActiveVent>0</distActiveVent>
   <maxAmplitude>1532.3</maxAmplitude>
   <sampleRate>0.01</sampleRate>
   <earthquakeType>TQ</earthquakeType>
  </SingleStationEvent>
  <SingleStationEvent code="VTAG_20160406000000" owner1="169" pubDate="2018-04-06 00:00:00" station="101">
   <startTime>2016-04-06 00:00:00</startTime>
   <startTimeCsec>0</startTimeCsec>
   <startTimeUnc>0000-00-00 00:00:01</startTimeUnc>
   <startTimeCsecUnc>0</startTimeCsecUnc>
   <picksDetermination>H</picksDetermination>
   <SPInterval>5.2</SPInterval>
   <duration>36</duration>
   <durationUnc>0</durationUnc>
   <distActiveVent>0</distActiveVent>
   <maxAmplitude>9435.1</maxAmplitude>
   <sampleRate>0.01</sampleRate>
   <earthquakeType>HFVQ(LT)</earthquakeType>
  </SingleStationEvent>
  <SingleStationEvent code="VTAG_20160407000000" owner1="169" pubDate="2018-04-07 00:00:00" station="101">
   <startTime>2016-04-07 00:00:00</startTime>
   <startTimeCsec>0</startTimeCsec>
   <startTimeUnc>0000-00-00 00:00:02</startTimeUnc>
   <startTimeCsecUnc>0</startTimeCsecUnc>
   <picksDetermination>H</picksDetermination>
   <SPInterval>2.3</SPInterval>
   <duration>19</duration>
   <durationUnc>0</durationUnc>
   <distActiveVent>0</distActiveVent>
   <maxAmplitude>549.3</maxAmplitude>
   <sampleRate>0.01</sampleRate>
   <earthquakeType>HFVQ(S)</earthquakeType>
  </SingleStationEvent>
 </SingleStationEventDataset>
 </Seismic>
 </Data>
</wovoml>
';

set @spec = '
<x show="true" exec="false" table="sd_evs" xpath="/wovoml/Data/Seismic/SingleStationEventDataset/SingleStationEvent">
  <x column="sd_evs_code"         xpath="@code"               expression=""/>
  <x column="ss_id"               xpath="@station"            expression="cast(ss_id as unsigned)"/>
  <x column="sd_evs_time"         xpath="startTime"           expression=""/>
  <x column="sd_evs_time_ms"      xpath="startTimeCsec"       expression=""/>
  <x column="sd_evs_time_unc"     xpath="startTimeUnc"        expression=""/>
  <x column="sd_evs_time_unc_ms"  xpath="startTimeCsecUnc"    expression=""/>
  <x column="sd_evs_picks"        xpath="picksDetermination"  expression=""/>
  <x column="sd_evs_spint"        xpath="SPInterval"          expression=""/>
  <x column="sd_evs_dur"          xpath="duration"            expression=""/>
  <x column="sd_evs_dur_unc"      xpath="durationUnc"         expression=""/>
  <x column="sd_evs_dist_actven"  xpath="distActiveVent"      expression=""/>
  <x column="sd_evs_maxamptrac"   xpath="maxAmplitude"        expression=""/>
  <x column="sd_evs_samp"         xpath="sampleRate"          expression=""/>
  <x column="sd_evs_eqtype"       xpath="earthquakeType"      expression=""/>
  <x column="cc_id"               xpath="@owner1"             expression=""/>
  <x column="sd_evs_pubdate"      xpath="@pubDate"            expression=""/>
</x>
';

call p_load_xml(@spec, @xml);