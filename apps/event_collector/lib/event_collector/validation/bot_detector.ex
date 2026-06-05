defmodule EventCollector.Validation.BotDetector do
  @moduledoc """
  Detects bot traffic based on user-agent string matching (FR-021).
  """

  @bot_patterns [
    ~r/bot/i,
    ~r/crawler/i,
    ~r/spider/i,
    ~r/scraper/i,
    ~r/curl/i,
    ~r/wget/i,
    ~r/python-requests/i,
    ~r/httpie/i,
    ~r/postman/i,
    ~r/googlebot/i,
    ~r/bingbot/i,
    ~r/slurp/i,
    ~r/duckduckbot/i,
    ~r/baiduspider/i,
    ~r/yandexbot/i,
    ~r/facebot/i,
    ~r/ia_archiver/i,
    ~r/headlesschrome/i,
    ~r/phantomjs/i,
    ~r/selenium/i
  ]

  @doc """
  Returns true if the user-agent indicates bot traffic.
  """
  def bot?(nil), do: false
  def bot?(""), do: false

  def bot?(user_agent) when is_binary(user_agent) do
    Enum.any?(@bot_patterns, fn pattern ->
      Regex.match?(pattern, user_agent)
    end)
  end

  @doc """
  Tag an event map with is_bot based on user-agent.
  """
  def tag_event(event, user_agent) do
    Map.put(event, "is_bot", bot?(user_agent))
  end
end
