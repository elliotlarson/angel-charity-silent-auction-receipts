defmodule Receipts.ChromicPDFHelperTest do
  use ExUnit.Case

  alias Receipts.ChromicPDFHelper

  describe "ensure_started/0" do
    test "returns :ok when ChromicPDF starts successfully" do
      assert ChromicPDFHelper.ensure_started() == :ok
    end

    test "returns :ok when ChromicPDF is already started" do
      ChromicPDFHelper.ensure_started()
      assert ChromicPDFHelper.ensure_started() == :ok
    end
  end
end
