defmodule Naiveical.Modificator do
  @moduledoc """
  Allows creation and modifications of an icalendar file.
  """

  alias Naiveical.Helpers
  alias Naiveical.Extractor

  @datetime_format_str "{YYYY}{0M}{0D}T{h24}{m}Z"

  def change_value_txt(ical_text, tag, new_value, new_properties) do
    {:ok, regex} = Regex.compile("^#{tag}[;]?.*:.*$", [:multiline])

    [{start_idx, str_len}] =
      Regex.run(regex, String.replace(ical_text, "\r\n", "\n"), return: :index)

    ics_before = String.slice(ical_text, 0, start_idx)
    ics_after = String.slice(ical_text, start_idx + str_len, String.length(ical_text))

    new_line =
      if String.length(new_properties) > 0 do
        "#{tag};#{new_properties}:#{new_value}"
      else
        "#{tag}:#{new_value}"
      end

    new_line = Helpers.fold(new_line)

    (ics_before <> "#{new_line}" <> ics_after)
    |> String.replace(~r/\r?\n/, "\r\n")
  end

  def change_value_txt(ical_text, tag, new_value) do
    {tag, properties, values} = Extractor.extract_contentline_by_tag(ical_text, tag)
    change_value_txt(ical_text, tag, new_value, "")
  end

  def change_value(ical_text, tag, new_value) when is_binary(new_value) do
    change_value_txt(ical_text, tag, new_value)
  end

  def change_value(
        ical_text,
        tag,
        datetime = %DateTime{
          year: year,
          month: month,
          day: day,
          zone_abbr: zone_abbr,
          hour: hour,
          minute: minute,
          second: second,
          microsecond: microsecond,
          utc_offset: utc_offset,
          std_offset: std_offset,
          time_zone: time_zone
        }
      ) do
    change_value_txt(ical_text, tag, Timex.format(datetime, "{ISO:Basic:Z}"))
  end

  @doc """
  Inserts another element (or any text) into the ical_text just before the ending of the element.
  """
  def insert_into(ical_text, new_content, element) do
    # normalize new element, add newlines if needed
    new_content =
      if String.match?(new_content, ~r/.*\r?\n/) do
        new_content
      else
        new_content <> "\r\n"
      end
      |> String.replace(~r/\r?\n/, "\r\n")

    if String.contains?(ical_text, "END:#{element}") do
      {:ok, regex} = Regex.compile("END:#{element}")

      [{start_idx, str_len}] =
        Regex.run(regex, String.replace(ical_text, "\r\n", "\n"), return: :index)

      ics_before = String.slice(ical_text, 0, start_idx)
      ics_after = String.slice(ical_text, start_idx, String.length(ical_text))

      {:ok,
       (ics_before <> "#{new_content}" <> ics_after)
       |> String.replace(~r/\r?\n/, "\r\n")}
    else
      {:error, "There is no ending of element #{element}"}
    end
  end

  @doc """
  Remove all elements of a specific type.
  """
  def delete_all(ical_text, tag) do
    if String.contains?(ical_text, "END:#{tag}") do
      ical_text = String.replace(ical_text, "\r\n", "\n")
      {:ok, regex_begin} = Regex.compile("BEGIN:#{tag}", [:multiline, :ungreedy])
      {:ok, regex_end} = Regex.compile("END:#{tag}", [:multiline, :ungreedy])

      begins = Regex.scan(regex_begin, ical_text, return: :index)
      ends = Regex.scan(regex_end, ical_text, return: :index)

      if length(begins) == length(ends) do
        [{first_begin_start, first_begin_length}] = Enum.at(begins, 0)
        [{last_end_start, last_end_length}] = Enum.at(ends, -1)

        last_part =
          String.slice(
            ical_text,
            last_end_start + last_end_length,
            String.length(ical_text) - last_end_start + last_end_length
          )

        new_ical =
          Enum.reduce(
            0..(length(begins) - 2),
            String.slice(ical_text, 0, first_begin_start - 1),
            fn i, acc ->
              [{end_start, end_length}] = Enum.at(ends, i)
              [{begin_start, begin_length}] = Enum.at(begins, i + 1)

              start_idx = end_start + end_length
              str_len = begin_start - (end_start + end_length) - 1

              acc <> String.slice(ical_text, start_idx, str_len)
            end
          ) <>
            last_part

        String.replace(new_ical, ~r/\r?\n/, "\r\n")
      else
        {:error, "BEGIN/END do not match"}
      end
    else
      ical_text
    end
  end
end
