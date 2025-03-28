"use client"

import { AgentApiState, AgentRequestBuildParams, CORTEX_ANALYST_TOOL, CORTEX_SEARCH_TOOL, DATA_TO_CHART_TOOL, SQL_EXEC_TOOL, useAgentAPIQuery } from "@/lib/agent-api";
import { useAccessToken } from "@/lib/auth";
import { Messages } from "./components/messages";
import { ChatInput } from "./components/input";
import { ChatHeader } from "./components/chat-header";

export default function Home() {
  // Agent API requires a JWT auth token. For simplicity we are using an api to fetch this,
  // but this can be easily replaced with a login layer and session management
  const { token: jwtToken } = useAccessToken();

  const tools: AgentRequestBuildParams['tools'] = [
    CORTEX_SEARCH_TOOL,
    CORTEX_ANALYST_TOOL,
    SQL_EXEC_TOOL,
  ]

  if (process.env.NEXT_PUBLIC_USE_DATA_TO_CHART === "true") {
    tools.push(DATA_TO_CHART_TOOL)
  }

  const { agentState, messages, latestMessageId, handleNewMessage } = useAgentAPIQuery({
    authToken: jwtToken,
    snowflakeUrl: process.env.NEXT_PUBLIC_SNOWFLAKE_URL!,
    experimental: {
      EnableRelatedQueries: true,
    },
    tools,
    toolResources: {
      "analyst1": { "semantic_model_file": process.env.NEXT_PUBLIC_SEMANTIC_MODEL_PATH },
      "search1": { "name": process.env.NEXT_PUBLIC_SEARCH_SERVICE_PATH, max_results: 10 },
    }
  })

  return (
    <>
      <div className="flex flex-col min-w-0 h-dvh bg-background">
        <ChatHeader />

        <Messages
          agentState={agentState}
          messages={messages}
          latestMessageId={latestMessageId}
        />

        <form className="flex mx-auto px-4 bg-background pb-4 md:pb-6 gap-2 w-full md:max-w-3xl">
          <ChatInput
            isLoading={agentState !== AgentApiState.IDLE}
            messagesLength={messages.length}
            handleSubmit={handleNewMessage} />
        </form>
      </div>
    </>
  );
}
